module assembler;

import common;
import parser;
import lexer;
import codegen;
import logger;

import std::io;

fn int main(String[] args)
{
  if (args.len != 3)
  {
    logger::error("must pass input file name and output file name");
    return 1;
  }
  char[] file_data = file::load_new(args[1])!!;
  File! out_file = file::open(args[2], "wb");
  if (catch err = out_file)
  {
    logger::error("Error while opening output file [%s]: %s ", args[2], err);
	return 1;
  }

  usz data_ptr = 0;
  logger::debug("Assembling:");
  logger::debug("---------------");
  $if $feature(DEBUG):
    io::eprintn((String)file_data);
  $endif
  logger::debug("---------------");

  Tokens! lexed = lexer::lex(file_data);
  if (catch err = lexed)
  {
    logger::error("Error while lexing tokens: %s", err);
	return 1;
  }
  defer lexed.free();

  logger::debug("lexed: %s", lexed);

  Prog! prog = parser::parse(lexed);
  if (catch err = prog)
  {
    logger::error("Error while parsing: %s", err);
    return 1;
  }
  defer prog.free();
  logger::debug("built: %s", prog);

 // foreach (i, tok : prog) generated.add_all(&&tok.to_bytes(&prog, i));

  Bytes! generated = codegen::generate(prog);
  if (catch err = generated)
  {
    logger::error("Error during generation: %s", err);
    return 1;
  }
  defer generated.free();

  $if $feature(DEBUG):
    logger::debug("generated:");
    foreach (ch : generated)
    {
      io::printf("%.2x", ch);
    }
    io::printn();
  $endif
  out_file.write(generated.array_view())!!;
  out_file.close()!!;


  return 0;
}

module codegen;

import common;
import logger;
import parser;

import std::io;

fault CodeGenError
{
	LABEL_NOT_FOUND,
}

fn usz Instruction.calculate_offset(self, Prog* prog, usz own_idx)
{
	usz offset;
	foreach (inst : prog.array_view()[..own_idx])
	{
		offset += inst.get_size();
	}
	return offset;
}

fn usz Instruction.get_size(self)
{
	usz size;
	foreach (arg : self.args[:self.type.args.count])
	{
		switch (arg.type)
		{
			case IMM:
				size += self.width;
			case REG:
				size += 1;
			case LABEL:
				size += BitWidth.W64;
			default:
				logger::panic("a: %s", arg.type);
		}
		//size +=
		//logger::debug("%s", arg);
	}
	return size;
}

fn isz! Instruction.resolve_label_offset(self, Prog* prog, usz own_idx, String label_name)
{
	foreach (i, inst : prog)
	{
		if (inst.label == label_name)
		{
			return self.calculate_offset(prog, own_idx) - inst.calculate_offset(prog, own_idx);
		}
	}
	codegen_error(self, "Label '%s' not found", label_name);
	return CodeGenError.LABEL_NOT_FOUND?;
}

fn Bytes! Instruction.to_bytes(self, Prog* prog, usz own_idx)
{
	Bytes b;
	b.temp_init();
	b.push(self.type.ordinal);
	b.push(self.width.ordinal);
	foreach (arg : self.args)
	{
		logger::debug("%s", arg);
		switch (arg.type)
		{
			case REG:
				b.push(arg.as_REG);
			case IMM:
				@eachif(self.width; $width)
				{
					char[$width] buf;
					buf[..].set($width, @as($typefrom($width.type), arg.as_IMM));
					b.add_array(&buf);
				};
			case LABEL:
				char[BitWidth.W64] buf;
				buf[..].set(W64, self.resolve_label_offset(prog, own_idx, arg.as_LABEL)!);
				b.add_array(&buf);
			default:
				logger::panic("%s not implented yet", arg.type);
		}
	}
//	logger::panic("Not implemented");
	return b;
}

fn Bytes! generate(Prog prog)
{
	Bytes bytes;
	bytes.new_init();

	foreach (i, inst : prog) @pool()
	{
		Bytes b = inst.to_bytes(&prog, i)!;
		bytes.add_all(&b);
	};

	return bytes;
}

macro codegen_error(Instruction inst, String message, ...)
{
	io::eprintf("Error on instruction '%s'", inst);
	io::eprintfn(message, $vasplat);
}

