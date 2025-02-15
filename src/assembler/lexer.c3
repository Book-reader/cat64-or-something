module lexer;

import common;
import logger;

import std::io;
import std::thread;
import std::collections::list;

const char COMMENT = '#';

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

fn Tokens! lex(char[] data)
{
	Tokens tokens;
	tokens.new_init();

	DString lexme;
	lexme.new_init();
	defer lexme.free();

	usz line_num = 1;
	usz char_pos = 1;

	bool in_comment;
	foreach (ch : data)
	{
		if (in_comment)
		{
			if (ch == '\n')
			{
				in_comment = false;
			}
			else
			{
				continue;
			}
		}
		if (ch == COMMENT)
		{
			in_comment = true;
			logger::debug("In comment at %s:%s", line_num, char_pos);
			continue;
		}
		if (ch == '\n')
		{
			line_num ++;
			char_pos = 1;
		}

		if (SEPERATORS.contains_char(ch))
		{
			if (lexme.len() != 0)
			{
				logger::debug("Found token '%s'", lexme);
				TokenType! token_type = get_token_type(lexme.str_view());
				if (catch err = token_type)
				{
					lex_error(line_num, char_pos, "Unsupported data '%s'", lexme.str_view());
					return err?;
				}
				tokens.push({token_type, lexme.copy_str(), line_num, char_pos});
				lexme.clear();
			}
			if (EOEXPR.contains_char(ch) && tokens.len() > 0 && tokens.last()!!.type != EOEXPR)
			{
				tokens.push({EOEXPR, string::new_format("%c", ch), line_num, char_pos});
			}
			if (ch == ',') tokens.push({ARG_SEP, ",", line_num, char_pos});
		}
		else
		{
			lexme.append_char(ch);
		}
		char_pos ++;
	}

	return tokens;
}

fn TokenType! get_token_type(String lexme)
{
	switch
	{
		case check_valid_instruction(lexme): return INSTRUCTION;
		case is_valid_register(lexme): return REGISTER;
		case is_valid_number(lexme): return NUMBER;
		case is_valid_label(lexme): return LABEL;
		case is_valid_label_decl(lexme): return LABEL_DECL;
		default: return LexingError.INVALID_DATA?;
	}
}

fault LexingError
{
	INVALID_DATA,
}

macro lex_error(usz line, usz pos, String message, ...)
{
	io::eprintf("Error at %s:%s ", line, pos);
	io::eprintfn(message, $vasplat);
}
