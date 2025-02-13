module codegen;

import common;
import logger;
import parser;

import std::io;

fault CodeGenError
{
	LABEL_NOT_FOUND,
}

fn usz Instruction.calculate_offset(self, Prog* prog, usz own_idx)
{
	usz offset;
	foreach (inst : prog.array_view()[:own_idx])
	{
		logger::debug("instruction %s, offset %s", inst, inst.get_size());
		offset += inst.get_size();
	}
//	offset += self.get_size();
	return offset;
}

fn usz Instruction.get_size(self)
{
	usz size = 2; // InstructionType + BitWidth;
	foreach (arg : self.args[:self.type.args.count])
	{
		switch (arg.type)
		{
			case IMM:
				size += self.width;
			case REG:
				size += 1;
			case LABEL:
				size += BitWidth.W64;
			default:
				logger::panic("not implemented: %s", arg.type);
		}
	}
	return size;
}

fn isz! Instruction.resolve_label_offset(self, Prog* prog, usz own_idx, String label_name)
{
	foreach (i, inst : prog)
	{
		if (inst.label == label_name)
		{
			logger::debug("label %s: own offset is %s, matching offset is %s, difference is %s", label_name, self.calculate_offset(prog, own_idx), inst.calculate_offset(prog, i), @as(isz, inst.calculate_offset(prog, i) - self.calculate_offset(prog, own_idx) - 2));
			return inst.calculate_offset(prog, i) - self.calculate_offset(prog, own_idx) - 2;
		}
	}
	codegen_error(self, "Label '%s' not found", label_name);
	return CodeGenError.LABEL_NOT_FOUND?;
}

fn Bytes! Instruction.to_bytes(self, Prog* prog, usz own_idx)
{
	Bytes b;
	b.temp_init();
	b.push(self.type.ordinal);
	b.push(self.width.ordinal);
	foreach (arg : self.args[:self.type.args.count])
	{
		logger::debug("%s", arg);
		logger::debug("before: %s", b);
		switch (arg.type)
		{
			case REG:
				b.push(arg.as_REG);
			case IMM:
				@eachif(self.width; $width)
				{
					char[$width] buf;
					buf[..].set($width, @as($typefrom($width.type), arg.as_IMM));
					logger::debug("%s: %s", $width, buf);
					b.add_array(buf[..]);
				};
			case LABEL:
				char[BitWidth.W64] buf;
				buf[..].set(W64, self.resolve_label_offset(prog, own_idx, arg.as_LABEL)!);
				b.add_array(&buf);
			default:
				logger::panic("%s not implented yet", arg.type);
		}
		logger::debug("after:  %s", b);
	}
	return b;
}

fn Bytes! generate(Prog prog)
{
	Bytes bytes;
	bytes.new_init();

	foreach (i, inst : prog) @pool()
	{
		Bytes b = inst.to_bytes(&prog, i)!;
		bytes.add_all(&b);
		if (inst.type == EXIT) logger::debug("EXIT offset: %s", inst.calculate_offset(&prog, i));
	};

	return bytes;
}

macro codegen_error(Instruction inst, String message, ...)
{
	io::eprintf("Error on instruction '%s'", inst);
	io::eprintfn(message, $vasplat);
}


