module emulator;
import common;
import logger;

import std::io;
import std::thread;
import std::time;
import std::collections::list;

struct ReadResult
{
	ulong diff;
	union
	{
		char as_W8;
		ushort as_W16;
		uint as_W32;
		ulong as_W64;
	}
}

macro ReadResult ReadResult.new(BitWidth $width, usz diff, val) @operator(construct)
{
	ReadResult new = {.diff = diff};
	new.$eval("as_" +++ $width.nameof) = val;
	return new;
}

macro ReadResult.get(self, BitWidth $width) => self.$eval("as_" +++ $width.nameof);

interface Addressable
{
	fn void free();
	fn char get(ulong address);
	fn bool contains(ulong address);
	fn void set(ulong address, char value);
	fn char[] get_range(ulong address, ulong len);
	fn bool contains_range(ulong address, ulong len);
	fn void set_range(ulong address, char[] values);
}

struct MemoryManagementUnit
{
	List{Addressable} memory;
}

fn MemoryManagementUnit MemoryManagementUnit.new_init() @operator(construct)
{
	MemoryManagementUnit new;
	new.memory.new_init();
	return new;
}

fn void MemoryManagementUnit.free(&self)
{
	foreach (i : self.memory)
	{
		i.free();
	}
	self.memory.free();
}

fn Addressable! MemoryManagementUnit.request(&self, ulong address)
{
	foreach (mem : self.memory)
	{
		if (mem.contains(address)) return mem;
	}
	return MemoryError.OUT_OF_BOUNDS?;
}

fn bool MemoryManagementUnit.contains(&self, ulong address) => @ok(self.request(address));

fault MemoryError
{
	OUT_OF_BOUNDS,
	NO_READ,
	NO_WRITE,
}

struct Memory// (Addressable)
{
	char[] ram;
	ulong offset;
}

fn void Memory.new_init(&self, usz size, usz offset = 0)
{
	self.offset = offset;
	self.ram = mem::new_array(char, size);
}

fn void Memory.free(&self) @dynamic
{
	mem::free(self.ram);
}

/*fn bool Memory.contains(self, ulong addr) @inline => addr - self.offset < self.ram.len;
// TODO: paging, it will also need to be a cpu flag
fn char Memory.get(self, ulong addr) @inline => self.ram[addr-self.offset:len];
fn void Memory.set(&self, ulong addr, char new) @inline => self.ram[addr-self.offset] = new;

fn bool Memory.contains_range(self, ulong start_addr, ulong len) @inline => self.contains(start_addr) && self.contains(start_addr + len - 1);
fn char[] Memory.get_range(self, ulong start_addr, ulong len) @inline => self.ram[start_addr-self.offset:len];
fn void Memory.set_range(self, ulong start_addr, ulong len, char[] new) @inline => self.ram[start_addr-self.offset:len] = new[:len];*/

fn bool Memory._contains(self, ulong addr) @inline => addr - self.offset < self.ram.len;

fn bool Memory.contains(self, ulong start_addr, ulong len) @inline => self._contains(start_addr) && self._contains(start_addr + len - 1);
fn char[] Memory.get(self, ulong start_addr, ulong len) @inline => self.ram[start_addr-self.offset:len];
fn void Memory.set(self, ulong start_addr, ulong len, char[] new) @inline => self.ram[start_addr-self.offset:len] = new[:len];

def Register = ulong;

macro Register.write(&self, BitWidth $width, data)
{
	logger::debug("Writing %s (0x%x) as %s", data, data, $width);
	self.$eval("write_" +++ $width.nameof)(data);
	logger::debug("Self is now %s (0x%x)", *self, *self);
}

fn void Register.write_W8(&self, char data) => *self = (*self & ~0x00000000000000ff) | @as(usz, data);

fn void Register.write_W16(&self, ushort data) => *self = (*self & ~0x000000000000ffff) | @as(usz, data);

fn void Register.write_W32(&self, uint data) => *self = (*self & ~0x00000000ffffffff) | @as(usz, data);

// Whoops, looks like this is a feature now
// I should probably remove this at some point
fn void Register.write_W64(&self, ulong data) => *self = ((Register) data).read_W64();


macro Register.read(&self, BitWidth $width) => self.$eval("read_" +++ $width.nameof)();

fn char Register.read_W8(self) => @as(char, self & 0x00000000000000ff);

fn ushort Register.read_W16(self) => @as(ushort, self & 0x000000000000ffff);

fn uint Register.read_W32(self) => @as(uint, self & 0x00000000ffffffff);

fn ulong Register.read_W64(self) => self;

bitstruct CpuFlags : Register
{
	bool zero : 0;
	bool carry : 1;
	bool overflow : 2;
	bool paging : 3;
}

struct Cpu
{
	// The address of the current instruction in memory
	Register* inst_ptr; // a pointer to regs[9];
	Register* stack_ptr; // A pointer to regs[8];
	Register* syscl_addr; // A pointer to regs[10];
	Register* syscl_ret; // A pointer to regs[11];
	CpuFlags* flags;
	Register[common::NUM_REGISTERS] regs;
	// TODO: make these a register, but have the pointer cast to a bitstruct containing these and other flags
//	bool f_zero;
	// if gt
//	bool f_carry;
}

fn void Cpu.init(&self)
{
	self.regs = {};
	self.inst_ptr = &self.regs[9];
	self.stack_ptr = &self.regs[8];
	self.syscl_addr = &self.regs[10];
	self.syscl_ret = &self.regs[11];
	self.flags = (CpuFlags*)&self.regs[12];
}

Memory mem;
// TODO: multithreading by sending data between cpu structs with an array and a mutex
//tlocal Cpu cpu;


fn int main(String[] args)
{
	Cpu cpu;
	cpu.init();
	mem.new_init(common::MEM_SIZE);
	defer mem.free();
	InstructionType test = inst::JMP;
	BitWidth test2 = W32;
//	Instruction test = {.real = true, .type = MOV, .width = W64, .src_type = REGPTR, .dst_type = REG};
//{.real = true, .type = JIF, .jif_cond = NE, .width = W8, .dst_type = NUM};//{.real = true, .type = JIF, .width = W8, .src_type = NUM, .dst_type = REG};
//{.real = true, .type = JIF, .jif_cond = NE, .offset_kind = SRC, .width = W8, .dst_type = NUM};//{.real = true, .type = MOV, .width = W64, .src_type = NUM, .dst_type = REG};
	//{.real = true, .type = JIF, .jif_cond = NE, .offset_kind = SRC, .width = W8, .src_type = PTR,.dst_type = PTR}; // {.type = CMP, .width = W8, .src_type = REGPTR, .dst_type = NUM, .offset_kind = NONE, .real = true };
//	char[2] a;
//	set_W16(&a, (InstSize)test);
	logger::debug("test: %.2x %.2x 00b6: \u00b6", test, test2);

	char[] prog;

	if (args.len > 1)
	{
/*		if (args[0] == "test")
		{
			prog = args[1];
		}
		else
		{*/
		prog = file::load_new(args[1])!!;
//		}
	}
	else
	{
		prog = x"340301ff00000000000000330000013c000003030101000000000000001c0000001503e8ffffffffffffff3b033a03";
	}
	defer if (args.len > 1 && args[0] != "test") free(prog);


	mem.set(0, prog.len, prog);

/*	if (args.len > 2)
	{
		mem.set(0xff, args[2].len, args[2]);
	}
	else
	{
		String msg = "Hello, World!\n\0";
		mem.set(0xff, msg.len, msg);
	}*/


	logger::debug("Executing (%s b): %h", prog.len, prog);

	bool running = true;

	// io::printfn("%.4x %.4x %.4x", @common::to_usize(W16, prog[0:2]), @common::to_usize2(W16, prog[0:2]), @common::to_usize3(W16, prog[0:2]));

	$if $feature(PERF):
		usz iteration = 0;
		Clock clock = clock::now();
	$endif

	Instruction inst;
//	while (running)
	{
		switch (inst::GET_) @jump
		{
			case inst::NOP: nextcase inst::BREAK;//nextcase;
			case inst::GET:
				// TODO: set a clock speed
				$if $feature(DELAY):
					thread::sleep(1000000);
				$endif
				// self.move_forward(inst, width);

				nextcase;
			case inst::GET_:
				$if $feature(PERF):
					iteration += 1;
					if ((iteration % 50000000) == 0)
					{
		//				running = false; //1000000000
						NanoDuration nano_seconds = clock.mark(); 
						io::eprintfn("\nTook %s or %s ns to do %s iterations, %dMhz", nano_seconds, @as(long, nano_seconds), iteration, (@as(double, iteration) /	nano_seconds.to_sec() / 1000000).round() );
						// thread::sleep(time::sec(1));
						iteration = 0;
						clock = clock::now();
						// continue;
					}
		//			if (iteration % 5000000 == 0) io::printfn("CPU Cycle: %s", iteration);
				$endif
				logger::debug("inst: %s", mem.get(*cpu.inst_ptr, 2));
		
				inst = (Instruction)mem.get(*cpu.inst_ptr, 2).get(W16);
				$foreach ($field : Instruction.membersof)
					logger::debug("inst.%s = %s", $field.nameof, inst.$eval($field.nameof));
				$endforeach
				logger::debug("%s -> %.2x.%.2x (0x%%.2x.0x%%.2x)", *cpu.inst_ptr, inst.type, inst.width);
		//		logger::debug("%s: %.4x -> %s.%s %s, %s", *cpu.inst_ptr, @as(InstSize, inst), inst.type, inst.width, inst.type == JIF ? inst.jif_cond.nameof : inst.dst_type.nameof, inst.src_type);
		
		
				// Big brain error checking
		//		if (!inst.real)
		//		{
		//			logger::error("Invalid instruction: %.4x", @as(InstSize, inst));
		//			running = false;
		//			continue;
		//		}
		
				// Point at the next byte
				*cpu.inst_ptr += 2;
		
				// Execute the current instruction
				nextcase inst.type;
			case inst::BREAK:
				return 0;

			case inst::ADD:
				cpu.inst_add(inst);
				nextcase inst::GET;
			default:
				logger::error("Instruction 0x%.2x is not implemented yet", inst.type);
				nextcase inst::BREAK;

/*			case PRINTI:
			case MOV:
			case ADD:
				// TODO: add directly instead of loading both, adding, and replacing as it will be more efficient
				@each_width(width; BitWidth $width)
				{
					write_reg(0, $width, @as($typefrom($width.type), read_reg(0, $width) + read_reg(1, $width)));
				};
			case EXIT:
				running = false;
				continue;
			case NOP:
				break;
			default:
				logger::error("Instruction %s not implemented yet", inst);
				return 1;*/
		}
	}
	$if $feature(PERF):
		NanoDuration nano_seconds = clock.mark(); 
		io::printfn("Took %s or %s ns to do %s iterations, %dMhz", nano_seconds, @as(long, nano_seconds), iteration, (@as(double, iteration) /	nano_seconds.to_sec() / 1000000).round() );
	$endif

	return 0;
}

macro Cpu.inst_nop(self, BitWidth width)
{
	return;
}


macro Cpu.inst_add(&self, Instruction inst) => @each_width(inst.width; BitWidth $width)
{
	// switch (inst.dst)
	self.write_reg(0, $width, @as($typefrom($width.type), self.read_reg(0, $width) + self.read_reg(1, $width)));
	self.move_forward($width, inst::ADD, inst);
}
fn void Cpu.unimplemented(self, BitWidth width) @deprecated("you should implement this instruction")
{
	logger::panic("Instruction %.2x not implemented yet", mem.get(*self.inst_ptr - 2, 2).get(W16));
}

macro invalid_instruction(...)
{
	logger::panic("Invalid instruction 0x%x %s %s %s %s", $vasplat, $vasplat);
}

macro void @each_width(BitWidth width; @body(BitWidth $width))
{
	switch (width)
	{
		case W8:
			@body(W8);
		case W16:
			@body(W16);
		case W32:
			@body(W32);
	}
}

macro @as_width(BitWidth $width, #expr, bool $signed = false)
{
	$if $signed:
		return @as($typefrom($width.itype), #expr);
	$else
		return @as($typefrom($width.type), #expr);
	$endif
}

macro Cpu.read_imm(&self, usz $offset, BitWidth $width, bool $signed = false)
{
	$if $signed:
		return @as($typefrom($width.itype),  mem.get(*self.inst_ptr + $offset, $width).get($width));
	$else
		return @as($typefrom($width.itype), mem.get(*self.inst_ptr + $offset, $width).get($width));
	$endif
}

<*
 @require @typeis(value, $typefrom($width.type)) ||| @typeis(value, $typefrom($width.itype))
*>
macro void Cpu.write_reg(&self, usz offset, BitWidth $width, value)
{
	self.regs[mem.get(*self.inst_ptr + offset, 1).get(W8)].write($width, value);
}

macro Cpu.read_reg(&self, usz offset, BitWidth $width, bool $signed = false)
{
	$if $signed:
		return @as($typefrom($width.itype), self.regs[mem.get(*self.inst_ptr + offset, 1).get(W8)].read($width));
	$else
		return @as($typefrom($width.type), self.regs[mem.get(*self.inst_ptr + offset, 1).get(W8)].read($width));
	$endif
}

macro Cpu.move_forward(&self, BitWidth $width, InstructionType $type, Instruction inst)
{
	// *self.inst_ptr += $width.size * 2;
	if (inst.has_offset)
	{
		*self.inst_ptr += 2;
	}
	$switch (inst::arg_count($type))
		$case 1:
			*self.inst_ptr += arg_size(inst.src, $width);
		$case 2:
			*self.inst_ptr += arg_size(inst.src, $width);
			*self.inst_ptr += arg_size(inst.dst, $width);
		$case 0:
	$endswitch

	/*$for (var $i = 0; $i < $inst.args.count; $i++)
		$switch ($inst.args.arg[$i])
			$case REG:
				*self.inst_ptr += common::REG_SIZE;
			$case REGOFF:
				*self.inst_ptr += common::REG_SIZE + common::OFF_SIZE;
			$case IMM:
				*self.inst_ptr += $width.size;
		$endswitch
	$endfor*/
}

macro arg_size(ArgType type, BitWidth $width)
{
	switch (type)
	{
		case REG:
		case REG_PTR:
			return 1;
		case IMM:
			return $width.size;
		case IMM_PTR:
			return common::PTR_SIZE;
	}
}
