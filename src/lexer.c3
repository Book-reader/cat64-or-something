module lexer;

import common;

import std::io;
import std::collections::list;

def Expr = List(<Token>);
def Prog = List(<Expr>);

struct Token(Printable)
{
  String lexme;
  TokenType type;
  String label;
}

fn usz! Token.to_format(&self, Formatter* formatter) @dynamic
{
  return formatter.printf("'%s':%s", self.lexme, self.type);
}

enum TokenType : char
{
  STRING,
  CHAR,
  NUMBER,
  INSTRUCTION,
  REGISTER,
  DEREF,
  DEREF_END,
//  LABEL_DECL,
  LABEL,
  ARG_SEP,
}


/*
const String[] VALID_SUFFIXES = {"8", "16", "32", "64"};

const String[common::NUM_REGISTERS] REG_NAMES = {"r0", "r1", "r2", "r3", "r4", "r5", "r6", "r7"};

const char COMMENT = ';';

fn bool String[].contains(&self, String pointer)
{
  return @ok(self.index_of(pointer));
}

fn usz! String[].index_of(&self, String pointer)
{
  foreach (i, val : self)
  {
    if (val == pointer) return i;
  }
  return SearchResult.MISSING?;
}


fn bool String.contains_char(s, char needle)
{
	return @ok(s.index_of_char(needle));
}

//fn 
fault InstructionFault
{
  NOT_INSTRUCTION,
  SIZE_IN_UNSIZED_INSTRUCTION,
  NO_SIZE_IN_SIZED_INSTRUCTION,
  INCORRECT_SIZE_PREFIX,
}

List(<String>) labels;

fn bool! check_valid_instruction(String data)
{
  io::printfn("checking inst: '%s'", data);
  $foreach ($instruction : InstructionType.values)
    if (data.len >= $instruction.name.len && data[0:$instruction.name.len] == $instruction.name)
    {
      if ($instruction.sized == false)
      {
        if (data.len == $instruction.name.len) return true;
        return InstructionFault.SIZE_IN_UNSIZED_INSTRUCTION?;
      }
      if (data.len > $instruction.name.len + 1 && data[$instruction.name.len] == '.' && VALID_SUFFIXES.contains(data[$instruction.name.len+1..])) return true;

      return InstructionFault.NO_SIZE_IN_SIZED_INSTRUCTION?;
    }
  $endforeach
  return false;
}

fn bool is_valid_register(String data)
{
  return REG_NAMES[..].contains(data);
}

fn bool is_valid_number(String data)
{
  if (catch err = data.to_int())
  {
    if (catch err2 = data.to_int(16))
    {
      return false;
    }
  }
  return true;
}

const String INVALID_LABEL = "0123456789.:";

fn bool is_valid_label_decl(String data)
{
  foreach (ch : data[0..data.len - 2])
  {
    if (INVALID_LABEL.contains_char(ch)) return false;
  }
  return data[data.len - 1] == ':';
}

fn bool is_valid_label(String data)
{
  foreach (ch : data)
  {
    if (INVALID_LABEL.contains_char(ch)) return false;
  }
  return true;
}

*/
const String SEPERATORS = {' ', ',', '\n', '\r', '\t', '\0'};
const char ARG_SEP = ',';

fn Prog! lex(char[] to_lex)
{
  Prog lexed;
/*  Tokens* curr_line;
  lexed.push({});
  curr_line = lexed.get_ref(lexed.len() - 1);
  String label;

  DString curr_tok;//.str_copy()

  bool in_string = false;

  for (int i = 0; i < to_lex.len; i++)
  {
    char ch = to_lex[i];

    if (ch == COMMENT)
    {
      while (to_lex[i] != '\n')
      {
        i++;
      }
      continue;
    }
    else if (ch == '"')
    {
   /*   if (curr_line.len() != 0)
      {
        common::error("found string in the middle of token");
      }
      else */if (!in_string)
      {
        in_string = true;
        continue;
      }
      else
      {
        lexed.push({ curr_line.copy_str(), STRING });
        curr_line.clear();
        continue;
      }
    }
    else if (ch == '\\')
    {
      curr_line.append(to_lex[++i]);
      continue;
    }
    else if (ch == '\'')
    {
      if (curr_line.len() != 0) common::error("Found char in the middle of token");
      ch = to_lex[++i];
      lexed.push( { String{ch}.copy(), CHAR } );
      if (to_lex[++i] != '\'') common::error("Error on char");
      continue;
    }

    if (!in_string)
    {
      if (ch == '[')
      {
        lexed.push({ "[", DEREF });
        continue;
      }
      else if (ch == ']')
      {
//        lexed.push({ "]", DEREF_END });
        continue;
      }
    }


    if (SEPERATORS.contains_char(ch))
    {
      TokenType t;
      if (curr_line.len() == 0)
      {
        continue;
      }
      else if (check_valid_instruction(curr_line.str_view())!)
      {
        t = INSTRUCTION;
      }
      else if (is_valid_register(curr_line.str_view()))
      {
        t = REGISTER;
      }
      else if (is_valid_number(curr_line.str_view()))
      {
        t = NUMBER;
      }
      else if (is_valid_label_decl(curr_line.str_view()))
      {
        //t = LABEL_DECL;
        label = curr_line.copy_str()[..curr_line.len() - 2];
        labels.push(label.copy());
//        labels.set(curr_line.copy_str()[..curr_line.len() - 2], -1);
      }
      else if (is_valid_label(curr_line.str_view()))
      {
        t = LABEL;
      }
      else
      {
        common::error("Unsupported data: '%s'", curr_line.str_view());
      }
      lexed.push({ curr_line.copy_str(), t, label });
      label = "";
      curr_line.clear();
      if (ch == ARG_SEP)
      {
        lexed.push({ String{ ch }.copy(), ARG_SEP, "" });
      }
      continue;
    }
    
    curr_line.append(ch);
  }*/
  return lexed;
}


