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
  ParseArgData[common::MAX_INST_ARGS] args;
  InstructionType type;
  BitWidth width;
  String label;
}

fn usz! Instruction.to_format(&self, Formatter* formatter) @dynamic
{
  usz! n;

  if (self.label != "") n += formatter.printf("(%s)", self.label);
  n += formatter.printf("%s%s:[", self.type.name, self.width.suffix);
  for (usz i = 0, usz len = self.type.args.count; i < len; i++)
  {
    n += formatter.printf("%s", self.args[i]);
    if (i < len - 1) n += formatter.print(",");
  }
  n += formatter.print("]");

  return n;
}

struct ParseArgData (Printable)
{
	ParseArgType type;
	union
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
}

fn usz! ParseArgData.to_format(&self, Formatter* formatter) @dynamic
{
	usz! n;
	switch (self.type)
	{
		case REG:
			n += formatter.printf("%s", common::REG_NAMES[self.as_REG]);
		case IMM:
			n += formatter.printf("%s", self.as_IMM);
		case LABEL:
			n += formatter.printf("%s", self.as_LABEL);
		case REGOFF:
			n += formatter.printf("%s(%s)", self.as_REGOFF.off, common::REG_NAMES[self.as_REGOFF.reg]);
	}
	return n;
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
	INCORRECT_ARG,
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
		prog.push(inst);
		inst = {};
	}
	return prog;
}

fn void! Instruction.build_start(&self, Tokens lexed, usz* idx)
{
	if (lexed[*idx].type == LABEL_DECL)
	{
		self.label = lexed[*idx].lexme.copy()[..^2];
		*idx += 1;
		switch (lexed[*idx].type)
		{
			case EOEXPR:
				*idx += 1;
			case INSTRUCTION:
				break;
			default:
				parse_error(lexed[*idx], "Expedted INSTRUCTION or EOEXPR but found '%s'", lexed[*idx].type);
				return ParseError.EXPECTED_INSTRUCTION?;
		}
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

// If parsargtype[i].runtime_type == instruction.args[i].type && parseargtype[i].valid_arg(arg)
fn void! Instruction.build_args(&self, Tokens lexed, usz* idx)
{
	if (self.type.args.count == 0) return;
	Tokens[common::MAX_INST_ARGS] args;
	ParseArgType[common::MAX_INST_ARGS] arg_types;
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

	// Calculate the types of the args here.
	foreach (i, arg : args[..arg_idx])
	{
		ParseArgType arg_type;
		switch
		{
			case arg.len() == 1 && arg[0].type == REGISTER:
				arg_type = REG;
			case arg.len() == 1 && (arg[0].type == NUMBER || arg[0].type == CHAR):
				arg_type = IMM;
			case arg.len() == 1 && arg[0].type == LABEL:
				arg_type = LABEL;
			case arg.len() == 2 && (arg[0].type == NUMBER || arg[0].type == CHAR) && arg[1].type == REGISTER:
				arg_type = REGOFF;
			default:
				parse_error(arg[0], "Unknown arg type '%s'. expected either REG, IMM, LABEL, or REGOFF", arg);
				return ParseError.INVALID_ARG?;
		}
		arg_types[i] = arg_type;
	}

	// Then compare the types against the expected types here
	foreach (i, arg : args[..arg_idx])
	{
		if (self.type.args.arg[i] == arg_types[i].runtime_type)
		{
			self.build_arg(arg, arg_types[i], i)!;
		}
		else
		{
			logger::error("arg: %s", arg);
			parse_error(arg[0], "expected arg type '%s' but found '%s'", self.type.args.arg[i], arg_types[i]);
			return ParseError.INCORRECT_ARG?;
		}
	}
}

fn void! Instruction.build_arg(&self, Tokens arg, ParseArgType arg_type, usz arg_idx)
{
	self.args[arg_idx].type = arg_type;
	switch (arg_type)
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
			self.args[arg_idx].as_LABEL = arg[0].lexme;
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
