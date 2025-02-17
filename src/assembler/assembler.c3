module assembler;

import common;
import parser;
import lexer;
import codegen;
import preprocessor;
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

  Bytes! preprocessed = preprocessor::process(file_data);
  if (catch err = preprocessed)
  {
    logger::error("Error while preprocessing: %s", err);
    return 1;
  }
  defer preprocessed.free();

  Tokens! lexed = lexer::lex(preprocessed.array_view());
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

module preprocessor;
import common;
import logger;
import lexer;
import std::io;
import std::collections::map;

def Aliases = HashMap(<String, String>);

fn Bytes! process(char[] data)
{
	Bytes all;
	all.new_init();

	Bytes line;
	@pool()
	{
		line.temp_init();
		foreach (ch : data)
		{
			line.push(ch);
			if (ch == '\n')
			{
				process_line(&line)!;
				all.add_all(&line);
				line.clear();
			}
		}
	};

	return all;
}

fault PreprocessorError
{
	INVALID_DIRECTIVE,
}

Aliases aliases;

fn void! process_line(Bytes* line)
{
	if (line.len() == 1) return;
	logger::debug("Preprocessing line '%s'", (String)line.array_view()[:^1]);
	String line_s = @as(String, line.array_view()[:^1]);
	if (line.get(0) == '@')
	{
		String directive = line_s[:line_s.index_of(" ")!];
		switch (directive)
		{
			case "@include":
				logger::debug("Found @include");
				Bytes! new = process(file::load_new(line_s[line_s.index_of(" ") + 1..]));
				if (catch err = new)
				{
					io::eprintfn("Error with directive '%s'", line_s);
					return err?;
				}
				line.free();
				*line = new;
			case "@define":
				String the_part = line_s[line_s.index_of(" ")! + 1..];
				String name = the_part[:the_part.index_of(" ")!].copy();
				String alias = the_part[the_part.index_of(" ")! + 1..].copy();
				logger::debug("defining %s as %s", name, alias);
				aliases.set(name, alias);
				line.clear();
			case "@undefine":
				aliases.remove(line_s[line_s.index_of(" ")! + 1..]);
				line.clear();
			default:
				io::eprintfn("Error: invalid preprocessor directive '%s'", directive);
				return PreprocessorError.INVALID_DIRECTIVE?;
		}
	}
	else if (line_s[0] != '#')
	{
		foreach (alias : aliases.iter())
		{
			logger::debug("key: %s, value: %s", alias.key, alias.value);
			if (line_s.contains(alias.key) && (line_s.index_of(alias.key)!! == 0 || lexer::SEPERATORS.contains_char(line_s[line_s.index_of(alias.key)!! - 1])) && (line_s.index_of(alias.key)!! + alias.key.len == line_s.len || lexer::SEPERATORS.contains_char(line_s[line_s.index_of(alias.key)!! + alias.key.len])))
			{
				usz start_idx = line_s.index_of(alias.key)!! == 0 ? 0 : line_s.index_of(alias.key)!! - 1;
				usz end_idx = line_s.index_of(alias.key)!! + alias.key.len == line_s.len ? line_s.len : line_s.index_of(alias.key)!! + alias.key.len;

				logger::debug("would be replaced as %s%s%s", line_s[..start_idx], alias.value, line_s[end_idx..]);
				line.clear();
				@pool()
				{
					*line.new_init_with_array(string::tformat("%s%s%s\n", start_idx == 0 ? "" : line_s[..start_idx], alias.value, line_s[end_idx..]));
				};
			}
		}
	}
}
