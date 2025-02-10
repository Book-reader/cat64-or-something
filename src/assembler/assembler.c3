module assembler;

import common;
import lexer;
import logger;

import std::io;
import std::collections::list;
import std::collections::tuple;

def Prog = List<[Instruction]>;
def Bytes = List<[char]>;

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
    logger::info("must pass input file name and output file name");
    return 1;
  }
  char[] file_data = file::load_new(args[1])!!;
  File out_file = file::open(args[2], "wb")!!;

  usz data_ptr = 0;
  logger::debug("Assembling:\n---------\n%s\n---------", (String)file_data);
  Tokens! lexed = lexer::lex(file_data);
  if (catch err = lexed)
  {
    logger::error("Error while lexing tokens: %s", err);
  }

  logger::debug("lexed: %s", lexed);

  Prog prog = build(lexed);
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

fn Prog build(Tokens lexed)
{
  logger::debug("building %s", lexed);
  Prog prog;

  Instruction inst;
  foreach (expr : lexed)
  {
    usz i;
    inst.build_start(expr, &i);

    inst.build_args(expr, &i);

    prog.push(inst);
    inst = {};
  }

/*  foreach (expr : lexed)
  {
    InstTok! tok = build_expr(expr);
    if (catch err = tok)
    {
      logger::error("error in expression '%s': %s", expr, err);
    }
    prog.push(tok);
  }*/

  return prog;
}

fn void Instruction.build_start(&self, Expr lexed, usz* idx)
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
        self.width = @enum_from_value(BitWidth, suffix, data[inst.name.len..]) ?? BitWidth.W64;
      }
    }
  }
  else
  {
    logger::error("Expected INSTRUCTION but found %s", lexed[*idx].type );
  }
}

fn void Instruction.build_args(&self, Expr lexed, usz* idx)
{
  Tokens args;
  args.new_init();
  defer args.free();
  Expr new_arg;
  new_arg.new_init();
//  defer arg.free();
  for (; *idx < lexed.len(); (*idx)++)
  {
    Token tok = lexed[*idx];
    logger::debug("tok: %s", tok);
    if (tok.type == INSTRUCTION) {}
    else if (tok.type == ARG_SEP)
    {
      args.push(new_arg);
      new_arg.new_init();
    }
    else
    {
      new_arg.push(tok);
    }
  }
  args.push(new_arg);
  logger::debug("Args: %s", args);

  logger::debug("Before args");

  foreach (i, arg : args)
  {
    logger::debug("In arg %s", i);
    if (i > self.type.args.count) logger::error("Too many arguments for instruction %s (%s)", self.type.name, arg);
    if (self.type.args.arg[i].valid_arg(arg))
    {
      switch (self.type.args.arg[i])
      {
        case REGOFF:
          logger::error("REGOFF not implemented yet");
          // self.args[i].as_REGOFF = { .reg = arg[0].lexme.to_uchar()!!, .off = arg[ };
        case IMM:
          ulong! imm = arg[0].lexme.to_ulong();
          if (catch err = imm)
          {
            imm = arg[0].lexme.to_ulong(16);
            if (catch err2 = imm)
            {
              logger::error("Invalid immediate: %s (%s)", err, arg[0].lexme);
            }
          }
          self.args[i].as_IMM = imm!!;
        case REG:
          self.args[i].as_REG = @as(char, common::REG_NAMES[..].index_of(arg[0].lexme)!!);
        case LABEL:
          logger::error("Not Implemented: %s", self.type.args.arg[i]);
      }
    }
    else
    {
      logger::error("Invalid arg (%s) for instruction %s", arg, self.type.name);
    }
  }
  logger::debug("self after parsing args: %s", self);
}

module std::collections::list(<Type>);

macro List List.new(...) @operator(construct)
{
  List new;
  new.new_init($vasplat);
  return new;
}
