module lexer;

import common;

import std::collections::list;

def Tokens = List(<Token>);

const String[] VALID_SUFFIXES = {"8", "16", "32", "64"};

const String[common::NUM_REGISTERS] REG_NAMES = {"r0", "r1", "r2", "r3", "r4", "r5", "r6", "r7"};

const char COMMENT = ';';

fn bool String[].contains(&self, String pointer)
{
  foreach (val : self)
  {
    if (val == pointer) return true;
  }
  return false;
}

fn bool is_valid_instruction(String data)
{
  bool is_valid_instruction = false;
  $foreach ($instruction : InstructionType.values)
    if (data.len >= $instruction.name.len && data[0:$instruction.name.len] == $instruction.name)
    {
      if ($instruction.sized == false && data.len == $instruction.name.len)
      {
        return true;
      }
      else if (data[$instruction.name.len] == '.', VALID_SUFFIXES.contains(data[$instruction.name.len+1..]))
      {
        return true;
      }
      return false;
    }
  $endforeach
  return is_valid_instruction;
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

fn bool is_valid_label_decl(String data)
{
  return data[data.len - 1] == ':';
}

struct Token
{
  String lexme;
  TokenType type;
}

enum TokenType
{
  STRING,
  CHAR,
  NUMBER,
  INSTRUCTION,
  REGISTER,
  DEREF,
  LABEL_DECL,
  LABEL,
}

const String SEPERATORS = {' ', ',', '\n', '\r', '\t', '\0'};

fn Tokens lex(char[] to_lex)
{
  Tokens lexed;
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
    }
    if (ch == '"')
    {
   /*   if (curr_tok.len() != 0)
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
        lexed.push({ curr_tok.copy_str(), STRING });
        curr_tok.clear();
        continue;
      }
    }

    if (ch == '\\')
    {
      curr_tok.append(to_lex[++i]);
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
        continue;
      }
    }

    if (SEPERATORS.contains({ch}))
    {
      TokenType t;
      if (curr_tok.len() == 0)
      {
        continue;
      }
      else if (is_valid_instruction(curr_tok.str_view()))
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
      else
      {
        t = LABEL;
        //common::error("Unsupported data: '%s'", curr_tok.str_view());
      }
      lexed.push({ curr_tok.copy_str(), t });
      curr_tok.clear();
      continue;
    }
    
    curr_tok.append(ch);
  }
  return lexed;
}


