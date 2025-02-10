module lexer;

import common;
import logger;

import std::io;
import std::thread;
import std::collections::list;

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

List<[String]> labels;

fn bool check_valid_instruction(String data)
{
  logger::debug("checking inst: '%s'", data);
  foreach (inst : InstructionType.values)
  {
    if (data.len >= inst.name.len && data[:inst.name.len] == inst.name)
    {
      if (data.len == inst.name.len) return true;
      foreach (width : BitWidth.values)
      {
        if (data[inst.name.len..] == width.suffix) return true;
      }
    }
  }
  return false;
}

fn bool is_valid_register(String data)
{
  return common::REG_NAMES[..].contains(data);
}

// there is totally not a better way to do this
// TODO: implement actual number checking, this is probably way too slow
fn bool is_valid_number(String data)
{
  if (catch err = data.to_ulong())
  {
    if (catch err2 = data.to_long())
    {
        return false;
    }
  }
  return true;
}

const String INVALID_LABEL = "0123456789.:";

fn bool is_valid_label_decl(String data)
{
  if (data[0] != '$') return false;
  foreach (ch : data[..^2])
  {
    if (INVALID_LABEL.contains_char(ch)) return false;
  }
  return data[^1] == ':';
}

fn bool is_valid_label(String data)
{
  if (data[0] != '$') return false;
  foreach (ch : data)
  {
    if (INVALID_LABEL.contains_char(ch)) return false;
  }
  return true;
}

const String SEPERATORS = {' ', ',', '\n', '\t', '\0', ';'};
const String EOEXPR = {';', '\n'};
const char ARG_SEP = ',';

fn Tokens! lex(char[] to_lex)
{
  Tokens lexed;
  Expr expr;

  DString curr_tok;//.str_copy()

  bool in_string = false;

  for (int i = 0; i < to_lex.len; i++)
  {
    char ch = to_lex[i];

    if (ch == COMMENT)
    {
      while (to_lex[i] != '\n' && i < to_lex.len)
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
      expr.push( { string::new_format("%c", ch), CHAR } );
      if (to_lex[++i] != '\'') logger::error("Error on char");
      continue;
    }

    if (in_string) continue;
    if (SEPERATORS.contains_char(ch))
    {
      logger::debug("curr tok: (%s) 0:%d", curr_tok.str_view());
      logger::debug("curr expr: %s", expr);
      TokenType t;
      if (curr_tok.len() == 0)
      {
        if (expr.len() == 0) continue;
      }
      else if (check_valid_instruction(curr_tok.str_view()))
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
        expr.push({ string::new_format("%c", ch), ARG_SEP });
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

//fn void expect()

fn void lex_error(usz line, String message, ...) @noreturn
{
  io::eprintf("Error: [line %s] ");
  io::eprintfn(message, $vasplat);
  thread::exit(1);
}
