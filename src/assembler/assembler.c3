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
  usz! n = formatter.printf("%s%s [", self.type.name, self.width.suffix);
  for (usz i = 0, usz len = self.type.args.count; i < len || {|n += formatter.print(","); return false;|}; i++)
  {
//    @eachif(self.type.args.arg[i]; $arg_type)
//    {
//      n += formatter.printf("%s");
//    };
  }
  n += formatter.print("]");

  return n;
}

union ArgData
{
  char as_REG;
  ulong as_IMM;
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
    inst = build_inst_start(expr, &i);
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

fn Instruction build_inst_start(Expr lexed, usz* i)
{
  Instruction new;
  if (lexed[*i].type == LABEL_DECL)
  {
    new.label = lexed[*i].lexme.copy()[:^2];
    *i += 1;
  }
  if (lexed[*i].type == INSTRUCTION)
  {
    String data = lexed[*i].lexme;
    foreach (inst : InstructionType.values)
    {
      if (data.len >= inst.name.len && data[:inst.name.len] == inst.name)
      {
        new.type = @enum_from_value(InstructionType, name, data[:inst.name.len])!!;
/*        if (data.len == inst.name.len)
        {
          new.width = W64;
        }
        else
        {*/
           new.width = @enum_from_value(BitWidth, suffix, data[inst.name.len..]) ?? BitWidth.W64;
        //}
      }
    }
  }
  else
  {
    logger::error("Expected INSTRUCTION but found %s", lexed[*i].type );
  }
  return new;
}

module std::collections::list(<Type>);

macro List List.new(...) @operator(construct)
{
  List new;
  new.new_init($vasplat);
  return new;
}
