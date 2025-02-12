module assembler;

import common;
import lexer;
import logger;

import std::io;
import std::collections::list;
import std::collections::tuple;

def Prog = List<[Instruction]>;

struct Instruction (Printable)
{
  ArgData[common::MAX_INST_ARGS] args;
  InstructionType type;
  BitWidth width;
  String label;
}

fn usz! Instruction.to_format(&self, Formatter* formatter) @dynamic
{
  usz! n = formatter.printf("%s%s:[", self.type.name, self.width.suffix);
  for (usz i = 0, usz len = self.type.args.count; i < len; i++)
  {
    switch (self.type.args.arg[i])
    {
      case REG:
        n += formatter.printf("%s", common::REG_NAMES[self.args[i].as_REG]);
      case IMM:
        n += formatter.printf("%s", self.args[i].as_IMM);
      case LABEL:
        n += formatter.printf("%s", self.args[i].as_LABEL);
      case REGOFF:
        n += formatter.printf("%s(%s)", self.args[i].as_REGOFF.off, common::REG_NAMES[self.args[i].as_REGOFF.reg]);
    }
    if (i < len - 1) n += formatter.print(",");
  }
  n += formatter.print("]");

  return n;
}

union ArgData// (Printable)
{
  char as_REG;
  ulong as_IMM;
  String as_LABEL;
  struct as_REGOFF
  {
    char reg;
    short off;
  }
}

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

  logger::debug("lexed: %s", lexed);

  Prog! prog = build(lexed);
  if (catch err = prog)
  {
    logger::error("Error while parsing: %s", err);
    return 1;
  }
  logger::debug("built: %s", prog);

  Bytes generated = Bytes.new();
 // foreach (i, tok : prog) generated.add_all(&&tok.to_bytes(&prog, i));

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

fault ParseError
{
	EXPECTED_INSTRUCTION,
	TOO_MANY_ARGS,
	NOT_ENOUGH_ARGS,
	INVALID_ARG,
	INVALID_IMMEDIATE,
}

fn Prog! build(Tokens lexed)
{
	logger::debug("building %s", lexed);
	Prog prog;

	Instruction inst;
	for (usz i = 0, usz len = lexed.len(); i < len; i++)
	{
		inst.build_start(lexed, &i)!;
		inst.build_args(lexed, &i)!;
		logger::debug("Inst %s", inst);
	}
	return prog;
}

fn void! Instruction.build_start(&self, Tokens lexed, usz* idx)
{
	if (lexed[*idx].type == LABEL_DECL)
	{
		self.label = lexed[*idx].lexme.copy()[:^2];
		*idx += 1;
	}
	if (lexed[*idx].type == INSTRUCTION)
	{
		String data = lexed[*idx].lexme;
		foreach (inst : InstructionType.values)
		{
			if (data.len >= inst.name.len && data[:inst.name.len] == inst.name)
			{
				self.type = @enum_from_value(InstructionType, name, data[:inst.name.len])!!;
				self.width = @enum_from_value(BitWidth, suffix, data[inst.name.len..]) ?? W64;
			}
		}
		*idx += 1;
	}
	else
	{
		parse_error(lexed[*idx], "Expected INSTRUCTION but found %s", lexed[*idx].type);
		return ParseError.EXPECTED_INSTRUCTION?;
	}
}

fn void! Instruction.build_args(&self, Tokens lexed, usz* idx)
{
	if (self.type.args.count == 0) return;
	Tokens[common::MAX_INST_ARGS] args;
	usz arg_idx;

	for ARG_COLLECTOR: (; *idx < lexed.len(); *idx += 1)
	{
		Token tok = lexed[*idx];
		switch (tok.type)
		{
			case EOEXPR:
				break ARG_COLLECTOR;
			case ARG_SEP:
				arg_idx ++;
			default:
				args[arg_idx].push(tok);
				if (arg_idx > self.type.args.count)
				{
					parse_error(tok, "Too many arguments for instruction '%s'", self.type.name);
					return ParseError.TOO_MANY_ARGS?;
				}

		}
	}
	if (arg_idx + 1 < self.type.args.count)
	{
		parse_error(args[arg_idx][^1], "Not enough arguments for instruction '%s' args: %s", self.type.name, args[..arg_idx]);
		return ParseError.NOT_ENOUGH_ARGS?;
	}

	foreach (i, arg : args[..arg_idx])
	{
		if (self.type.args.arg[i].valid_arg(arg))
		{
			self.build_arg(arg, i)!;
		}
		else
		{
			logger::error("arg: %s", arg);
			parse_error(arg[0], "Invalid arg '%s' for instruction '%s'", arg, self.type.name);
			return ParseError.INVALID_ARG?;
		}
	}
}

fn void! Instruction.build_arg(&self, Tokens arg, usz arg_idx)
{
	switch (self.type.args.arg[arg_idx])
	{
		case REGOFF:
			logger::panic("REGOFF not implemented yet");
			// self.args[i].as_REGOFF = { .reg = arg[0].lexme.to_uchar()!!, .off = arg[ };
		case IMM:
			ulong! imm = arg[0].lexme.to_ulong();
			if (catch err = imm)
			{
				parse_error(arg[0], "Invalid immediate: %s", err);
				return ParseError.INVALID_IMMEDIATE?;
			}
			self.args[arg_idx].as_IMM = imm;
		case REG:
			self.args[arg_idx].as_REG = @as(char, common::REG_NAMES[..].index_of(arg[0].lexme)!!);
		case LABEL:
			logger::panic("Not Implemented: %s", self.type.args.arg[arg_idx]);
	}
}


macro parse_error(Token tok, String message, ...)
{
	io::eprintf("Error at %s ", tok);
	io::eprintfn(message, $vasplat);
}

module std::collections::list(<Type>);

macro List List.new(...) @operator(construct)
{
	List new;
	new.new_init($vasplat);
	return new;
}
