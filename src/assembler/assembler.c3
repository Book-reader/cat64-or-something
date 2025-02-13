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

