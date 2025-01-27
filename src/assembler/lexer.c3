module lexer;

import common;
import logger;

import std::io;
import std::collections::list;

def Expr = List(<Token>);
def Prog = List(<Expr>);

struct Token(Printable)
{
  String lexme;
  TokenType type;
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
  LABEL,
  ARG_SEP,
  LABEL_DECL,
}



const String[BitWidth.elements] VALID_SUFFIXES = {"8", "16", "32", "64"};

$assert(VALID_SUFFIXES[0] == BitWidth.W8.name);

const String[common::NUM_REGISTERS] REG_NAMES = {"r0", "r1", "r2", "r3", "r4", "r5", "r6", "r7", "rsp", "esp"};

const char COMMENT = '#';

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
  logger::debug("checking inst: '%s'", data);
  $foreach ($instruction : InstructionType.values)
//    logger::debug("%s:%s %s:%s", data, data.len, $instruction.name, $instruction.name.len);
    if (data.len >= $instruction.name.len && data[0:$instruction.name.len] == $instruction.name)
    {
//      logger::debug("a");
      if ($instruction.sized == false)
      {
//        logger::debug("b");
        if (data.len == $instruction.name.len) return true;
        return InstructionFault.SIZE_IN_UNSIZED_INSTRUCTION?;
      }
      if (data.len > $instruction.name.len + 1 && data[$instruction.name.len] == '.' && VALID_SUFFIXES[..].contains(data[$instruction.name.len+1..])) return true;

      return InstructionFault.NO_SIZE_IN_SIZED_INSTRUCTION?;
    }
  $endforeach
  logger::debug("Not instruction :(");
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
  foreach (ch : data[..^2])
  {
    if (INVALID_LABEL.contains_char(ch)) return false;
  }
  return data[^1] == ':';
}

fn bool is_valid_label(String data)
{
  foreach (ch : data)
  {
    if (INVALID_LABEL.contains_char(ch)) return false;
  }
  return true;
}

const String SEPERATORS = {' ', ',', '\n', '\r', '\t', '\0', ';'};
const String EOEXPR = {';', '\n', '\r'};
const char ARG_SEP = ',';

fn Prog! lex(char[] to_lex)
{
  Prog lexed;
  Expr expr;

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
   /*   if (curr_tok.len() != 0)
      {
        logger::error("found string in the middle of token");
      }
      else */if (!in_string)
      {
        in_string = true;
        continue;
      }
      else
      {
        expr.push({ curr_tok.copy_str(), STRING });
        curr_tok.clear();
        continue;
      }
    }
    else if (ch == '\\')
    {
      curr_tok.append(to_lex[++i]);
      continue;
    }
    else if (ch == '\'')
    {
      if (curr_tok.len() != 0) logger::error("Found char in the middle of token");
      ch = to_lex[++i];
      expr.push( { String{ch}.copy(), CHAR } );
      if (to_lex[++i] != '\'') logger::error("Error on char");
      continue;
    }

    if (!in_string)
    {
      if (ch == '[')
      {
        expr.push({ "[", DEREF });
        continue;
      }
      else if (ch == ']')
      {
//        expr.push({ "]", DEREF_END });
        continue;
      }
    }


    if (in_string) continue;
    if (SEPERATORS.contains_char(ch))
    {
      TokenType t;
      if (curr_tok.len() == 0)
      {
        continue;
      }
      else if (check_valid_instruction(curr_tok.str_view())!)
      {
        t = INSTRUCTION;
      }
      else if (is_valid_register(curr_tok.str_view()))
      {
        t = REGISTER;
      }
      else if (is_valid_number(curr_tok.str_view()))
      {
        t = NUMBER;
      }
      else if (is_valid_label_decl(curr_tok.str_view()))
      {
        t = LABEL_DECL;
      }
      else if (is_valid_label(curr_tok.str_view()))
      {
        t = LABEL;
      }
      else
      {
        logger::error("Unsupported data: '%s'", curr_tok.str_view());
      }
      expr.push({ curr_tok.copy_str(), t });
      curr_tok.clear();
      if (ch == ARG_SEP)
      {
        expr.push({ String{ ch }.copy(), ARG_SEP });
      }

     if (EOEXPR.contains_char(ch) && ((expr.len() > 1 && expr[0].type == LABEL_DECL) || (expr.len() > 0 && expr[0].type == INSTRUCTION)))
     {
       logger::debug("expr is: %s", expr);
       logger::debug("eoexpr was: '%c' '%d'", ch, ch);
       lexed.push(expr);
       expr = {};
     }

      continue;
    }
    
    curr_tok.append(ch);
  }
  return lexed;
}


