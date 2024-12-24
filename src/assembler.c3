module assembler;

import common;
import lexer;

import std::io;
import std::collections::list;

enum PseudoInstruction : (String name, String into)
{
//  CALL = { "call", "push " }
}

fn int main(String[] args) @if($feature(ASSEMBLER))
{
  if (args.len != 3)
  {
    io::eprintn("must pass input file name and output file name");
    return 1;
  }
  char[] file_data = file::load_new(args[1])!!;
  usz data_ptr = 0;
  io::printfn("Assembling:\n---------\n%s\n---------", (String)file_data);
  Tokens lexed = lexer::lex(file_data);

  foreach (tok : lexed)
  {
    io::printfn("token '%s':%s", tok.lexme, tok.type);
  }

  List(<Instruction>) data =  validate_gen(lexed);

  return 0;
}

fn List(<Instruction>) validate_gen(Tokens lexed)
{
  List(<Instruction>) generated;

  Tokens collected; 
  Instruction curr_inst;
  foreach (token : lexed)
  {
    if (token.type != INSTRUCTION)
    {
      
    }
  }

  return generated;
}
