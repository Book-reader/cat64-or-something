module emulator;
import common;
import logger;

import std::io;
import std::thread;
import std::time;
import std::collections::list;

alias alloc = allocator::mem;

bitstruct Byte : ushort
{
	ushort val : 0..8;
}

bitstruct Word : uint
{
	uint val : 0..17;
}

bitstruct DWord : ulong
{
	ulong val : 0..35;
}

struct ReadResult
{
	uint diff;
	union
	{
		char as_W8;
		ushort as_W16;
		uint as_W32;
		uint as_W64;
	}
}

macro ReadResult new_readresult(BitWidth $width, uint diff, val)
{
	ReadResult new = {.diff = diff};
	new.$eval("as_" +++ $width.nameof) = val;
	return new;
}

macro ReadResult.get(self, BitWidth $width) => self.$eval("as_" +++ $width.nameof);

/*interface Addressable
{
	fn void free();
	fn char get(uint address);
	fn bool contains(uint address);
	fn void set(uint address, char value);
	fn char[] get_range(uint address, uint len);
	fn bool contains_range(uint address, uint len);
	fn void set_range(uint address, char[] values);
}

struct MemoryManagementUnit
{
	List {Addressable} memory;
}

fn void MemoryManagementUnit.new_init(&self)
{
	self.memory.init(alloc);
}

fn void MemoryManagementUnit.free(&self)
{
	foreach (i : self.memory)
	{
		i.free();
	}
	self.memory.free();
}

fn Addressable? MemoryManagementUnit.request(&self, uint address)
{
	foreach (mem : self.memory)
	{
		if (mem.contains(address)) return mem;
	}
	return OUT_OF_BOUNDS?;
}

fn bool MemoryManagementUnit.contains(&self, uint address) => @ok(self.request(address));

faultdef OUT_OF_BOUNDS, NO_READ, NO_WRITE;
*/


// Quick and dirty for now
/*struct Mmu
{
	int x;
}*/

fn char[] mmu_get(/*&self, */uint addr, uint len) @inline
{
	// cannot have overlap
	if (addr < common::RAM_SIZE && addr + len - 1 <= common::RAM_SIZE)
	{
		return mem.ram[addr:len];
	}
	else if (addr >= common::ROM_START && addr + len - 1 <= common::ROM_START + common::ROM_SIZE)
	{
		return mem.rom[addr-common::ROM_START:len];
	}
	else
	{
		abort("Out of range: 0x%.8x:%s", addr, len);
	}
}

fn void mmu_set(uint addr, uint len, char[] buf) @inline
{
	// cannot have overlap
	if (addr < common::RAM_SIZE && addr + len - 1 <= common::RAM_SIZE)
	{
		mem.ram[addr:len] = buf[:len];
	}
	else if (addr >= common::ROM_START && addr + len - 1 <= common::ROM_START + common::ROM_SIZE)
	{
		mem.rom[addr-common::ROM_START:len] = buf[:len];
	}
	else
	{
		abort("Out of range: 0x%.8x:%s", addr, len);
	}
}

struct Memory// (Addressable)
{
	char[] ram;
	char[] rom;
	//uint offset;
}

fn void Memory.init(&self)
{
	// self.offset = offset;
	self.ram = mem::new_array(char, common::RAM_SIZE);
	self.rom = mem::new_array(char, common::ROM_SIZE);
}

fn void Memory.free(&self) //@dynamic
{
	mem::free(self.ram);
	mem::free(self.rom);
}

/*fn bool Memory.contains(self, uint addr) @inline => addr - self.offset < self.ram.len;
// TODO: paging, it will also need to be a cpu flag
fn char Memory.get(self, uint addr) @inline => self.ram[addr-self.offset:len];
fn void Memory.set(&self, uint addr, char new) @inline => self.ram[addr-self.offset] = new;

fn bool Memory.contains_range(self, uint start_addr, uint len) @inline => self.contains(start_addr) && self.contains(start_addr + len - 1);
fn char[] Memory.get_range(self, uint start_addr, uint len) @inline => self.ram[start_addr-self.offset:len];
fn void Memory.set_range(self, uint start_addr, uint len, char[] new) @inline => self.ram[start_addr-self.offset:len] = new[:len];*/

// fn bool Memory._contains(self, uint addr) @inline => addr - self.offset < (uint)self.ram.len;

// fn bool Memory.contains(self, uint start_addr, uint len) @inline => self._contains(start_addr) && self._contains(start_addr + len - 1);
// fn char[] Memory.get(self, uint start_addr, uint len) @inline => self.ram[start_addr-self.offset:len];
// fn void Memory.set(self, uint start_addr, uint len, char[] new) @inline => self.ram[start_addr-self.offset:len] = new[:len];

alias Register = uint;

macro Register.write(&self, BitWidth $width, data)
{
	logger::debug("Writing %s (0x%x) as %s", data, data, $width);
	self.$eval("write_" +++ $width.nameof)(data);
	logger::debug("Self is now %s (0x%x)", *self, *self);
}

fn void Register.write_W8(&self, char data) => *self = (*self & ~0x000000ff) | @as(uint, data);

fn void Register.write_W16(&self, ushort data) => *self = (*self & ~0x0000ffff) | @as(uint, data);

fn void Register.write_W32(&self, uint data) => *self = data;

macro Register.read(&self, BitWidth $width) => self.$eval("read_" +++ $width.nameof)();

fn char Register.read_W8(self) => @as(char, self & 0x000000ff);

fn ushort Register.read_W16(self) => @as(ushort, self & 0x0000ffff);

fn uint Register.read_W32(self) => self;

bitstruct CpuFlags : Register
{
	bool zero : 0;
	bool carry : 1;
	bool exception_sp : 2;
	bool interrupt : 3;
	bool mmu : 4;
	bool page_directort : 5;
}

struct Cpu
{
	// The address of the current instruction in memory
	Register* stack_ptr; // A pointer to regs[32];
	Register* exception_ptr; // A pointer to regs[33];
	Register* frame_ptr; // A pointer to regs[34];
	Register* inst_ptr; // a pointer to regs[35];
	CpuFlags flags;
	Register[common::NUM_REGISTERS] regs;
}

<*
	@require len == buf.len
*>
fn void Cpu.mem_set(&self, uint start, uint len, char[] buf) @inline
{
	//if (!self.flags.mmu)
	//{
	//	mem.ram[start:len] = buf[:len];
	//}
	//else
	//{
		mmu_set(start, len, buf);
		// abort("MMU not implemented yet :3");
	//}
}

<*
	@ensure return.len == len
*>
fn char[] Cpu.mem_get(&self, uint start, uint len) @inline
{
	// TODO: make this unlikely using whatever stdlib macro
	//if (!self.flags.mmu)
	//{
	//	return mem.ram[start:len];
	//}
	//else
	//{
		return mmu_get(start, len);
		// abort("MMU not implemented yet :3");
	//}
}

fn void Cpu.init(&self)
{
	self.regs = {};
	self.stack_ptr = &self.regs[32];
	self.exception_ptr = &self.regs[33];
	self.frame_ptr = &self.regs[34];
	self.inst_ptr = &self.regs[35];
	*self.inst_ptr = common::DEFAULT_INST_PTR;
	*self.stack_ptr = common::DEFAULT_STACK_PTR;
	self.flags.mmu = true;
}

Memory mem;
// TODO: multithreading by sending data between cpu structs with an array and a mutex
//tlocal Cpu cpu;

// TODO: make all get instructions return a char[] so I can just do 'get_arg1()[:len] = get_arg2()[:len]' instead of all the bitmasks and switch statements and macros
// it will make memory to memory operations faster & I can have a reg->reg version as well
fn int main(String[] args)
{
	Cpu cpu;
	cpu.init();
	mem.init();
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

	usz max_cycles;
	usz iters;

	if (args.len > 1)
	{
/*		if (args[0] == "test")
		{
			prog = args[1];
		}
		else
		{*/
		prog = file::load(alloc, args[1])!!;

		if (args.len > 2)
		{
			max_cycles = args[2].to_int()!!;
		}
//		}
	}
	else
	{
		prog = x"340301ff00000000000000330000013c000003030101000000000000001c0000001503e8ffffffffffffff3b033a03";
	}
	defer if (args.len > 1 && args[0] != "test") free(prog);


	cpu.mem_set(common::DEFAULT_INST_PTR, prog.len, prog);
	// *cpu.inst_ptr = 0;
	// cpu.mem_set(0, prog.len, prog);

/*	if (args.len > 2)
	{
		mem.set(0xff, args[2].len, args[2]);
	}
	else
	{
		String msg = "Hello, World!\n\0";
		mem.set(0xff, msg.len, msg);
	}*/


	logger::debug("Executing (%s b): %h", prog.len, prog[:prog.len < 200 ? prog.len : 200]);

	bool running = true;

	// io::printfn("%.4x %.4x %.4x", @common::to_usize(W16, prog[0:2]), @common::to_usize2(W16, prog[0:2]), @common::to_usize3(W16, prog[0:2]));

	$if $feature(PERF):
		uint iteration = 0;
		Clock clock = clock::now();
	$endif

	Instruction inst;
//	while (running)
	{
		switch (inst::GET_) @jump
		{
			case inst::NOP: nextcase;
			case inst::GET:
				iters ++;
				if (iters == max_cycles)
				{
					logger::info("Hit max_cycles of %s, exiting", max_cycles);
					nextcase inst::BREAK;
				}
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
				logger::debug("Nearby mem: %s", cpu.mem_get(*cpu.inst_ptr, 10));
				
				// logger::debug("As instrs : %s", @as(Instruction[5]*, @as(char*, cpu.mem_get(*cpu.inst_ptr, 10)))[0][..]);
				inst = (Instruction)cpu.mem_get(*cpu.inst_ptr, 2).get(W16);

				// $foreach $field : Instruction.membersof:
				// 	logger::debug("inst.%s = %s", $field.nameof, inst.$eval($field.nameof));
				// $endforeach
				logger::debug("0x%.8x -> %s", *cpu.inst_ptr, inst);

				@each_width(inst.width; BitWidth $width)
				{
					uint addr = *cpu.inst_ptr + 2 + arg_size(inst.src, $width) + arg_size(inst.dst, $width) + (inst.has_offset ? 2 : 0);
					logger::debug("Next instruction at %.8x : %s", addr, (Instruction)cpu.mem_get(addr, 2).get(W16));
				};
		//		logger::debug("%s: %.4x -> %s.%s %s, %s", *cpu.inst_ptr, @as(InstSize, inst), inst.type, inst.width, inst.type == JIF ? inst.jif_cond.nameof : inst.dst_type.nameof, inst.src_type);
		
		
				// Big brain error checking
		//		if (!inst.real)
		//		{
		//			logger::error("Invalid instruction: %.4x", @as(InstSize, inst));
		//			running = false;
		//			continue;
		//		}
		
				// Point at the next byte
				*cpu.inst_ptr += common::INST_SIZE;
		
				// Execute the current instruction
				if (cpu.should_execute(inst))
				{
					nextcase inst.type;
				}
				else
				{
					nextcase inst::GET;
				}
			case inst::HALT:
			case inst::BREAK:
				foreach (i, reg : cpu.regs)
				{
					logger::info("%s: %.8x", common::REG_NAMES[i], reg);
				}
				return 0;

			case inst::ADD:
				cpu.inst_add(inst);
				nextcase inst::GET;
			case inst::SUB:
				cpu.inst_sub(inst);
				nextcase inst::GET;
			case inst::MUL:
				cpu.inst_mul(inst);
				nextcase inst::GET;
			case inst::DIV:
				cpu.inst_div(inst);
				nextcase inst::GET;
			case inst::MOV:
				cpu.inst_mov(inst);
				nextcase inst::GET;
			case inst::CMP:
				cpu.inst_cmp(inst);
				nextcase inst::GET;
			case inst::JMP:
				cpu.inst_jmp(inst);
				nextcase inst::GET;
			case inst::RJMP:
				cpu.inst_rjmp(inst);
				nextcase inst::GET;
			case inst::MCL:
				cpu.flags.mmu = false;
				nextcase inst::GET;
			case inst::MSE:
				cpu.flags.mmu = true;
				nextcase inst::GET;
			case inst::OUT:
				cpu.inst_out(inst);
				nextcase inst::GET;
			case inst::CALL:
				cpu.inst_call(inst);
				nextcase inst::GET;
			case inst::RET:
				cpu.inst_ret(inst);
				nextcase inst::GET;
			case inst::ISE:
				cpu.flags.interrupt = true;
				nextcase inst::GET;
			case inst::ICL:
				cpu.flags.interrupt = false;
				nextcase inst::GET;
			default:
				logger::error("Instruction %s is not implemented yet", inst.type.get_name());
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

fn bool Cpu.should_execute(&self, Instruction inst) @inline
{
	switch (inst.cond)
	{
		case ALWAYS:
			return true;
		case IFZ:
			return self.flags.zero;
		case IFNZ:
			return !self.flags.zero;
		case IFC: // same as: IFLT
			return self.flags.carry; 
		case IFNC: // same as: IFGTEQ
			return !self.flags.carry;
		case IFGT:
			return !self.flags.zero && !self.flags.carry;
		case IFLTEQ:
			return self.flags.zero || self.flags.carry;
			
	}
}

macro Cpu.inst_add(&self, Instruction inst) => @each_width(inst.width; BitWidth $width)
{
	var src = self.get_val($width, inst, src);
	var dst = self.get_val($width, inst, dst);
	logger::debug("Adding %s and %s", dst, src);
	self.set_val($width, inst, dst, @as($typefrom($width.type), dst + src));
	self.move_forward($width, inst::ADD, inst);
}

macro Cpu.inst_sub(&self, Instruction inst) => @each_width(inst.width; BitWidth $width)
{
	var src = self.get_val($width, inst, src);
	var dst = self.get_val($width, inst, dst);
	logger::debug("Subtracting %s and %s", dst, src);
	self.set_val($width, inst, dst, @as($typefrom($width.type), dst - src));
	self.move_forward($width, inst::SUB, inst);
}

macro Cpu.inst_mul(&self, Instruction inst) => @each_width(inst.width; BitWidth $width)
{
	var src = self.get_val($width, inst, src);
	var dst = self.get_val($width, inst, dst);
	logger::debug("multiplying %s and %s", dst, src);
	self.set_val($width, inst, dst, @as($typefrom($width.type), dst * src));
	self.move_forward($width, inst::MUL, inst);
}

macro Cpu.inst_div(&self, Instruction inst) => @each_width(inst.width; BitWidth $width)
{
	var src = self.get_val($width, inst, src);
	var dst = self.get_val($width, inst, dst);
	logger::debug("dividing %s by %s", dst, src);
	self.set_val($width, inst, dst, @as($typefrom($width.type), dst / src));
	self.move_forward($width, inst::DIV, inst);
}

macro Cpu.inst_mov(&self, Instruction inst) => @each_width(inst.width; BitWidth $width)
{
	var src = self.get_val($width, inst, src);
	logger::debug("Moving %s", src);
	self.set_val($width, inst, dst, src);
	self.move_forward($width, inst::MOV, inst);
}

macro Cpu.inst_cmp(&self, Instruction inst) => @each_width(inst.width; BitWidth $width)
{
	var src = self.get_val($width, inst, src);
	var dst = self.get_val($width, inst, dst);
	logger::debug("Comparing %s and %s", src, dst);
	self.flags.zero = src == dst;
	self.flags.carry = src > dst;
	self.move_forward($width, inst::MOV, inst);
}

macro Cpu.inst_jmp(&self, Instruction inst) => @each_width(inst.width; BitWidth $width)
{
	var src = self.get_val($width, inst, src);
	logger::debug("Jmping to 0x%.8x", src);
	*self.inst_ptr = src;
	// self.move_forward($width, inst::JMP, inst);
}

macro Cpu.inst_rjmp(&self, Instruction inst) => @each_width(inst.width; BitWidth $width)
{
	var src = self.get_val($width, inst, src);
	logger::debug("Jmping by %s", (int)src);
	*self.inst_ptr += (int)src - common::INST_SIZE;
	// self.move_forward($width, inst::JMP, inst);
}

extern fn CInt putchar(CInt c);

macro Cpu.inst_out(&self, Instruction inst) => @each_width(inst.width; BitWidth $width)
{
	var src = self.get_val($width, inst, src);
	var dst = self.get_val($width, inst, dst);
	if (dst != 0)
	{
		logger::warn("Out to not stdout is not supported yet: 0x%.8x", dst);
	}
	else
	{
		putchar((CInt)src) @inline;
	}
	// TODO: have a macro that wraps this & does something like: self.move_forward($width, $eval("inst::" +++ @to_upper($$FUNC[5..])), inst;
	self.move_forward($width, inst::OUT, inst);
}

macro Cpu.inst_call(&self, Instruction inst) => @each_width(inst.width; BitWidth $width)
{
	var src = self.get_val($width, inst, src);
	self.move_forward($width, inst::CALL, inst);
	self._push(W32, *self.inst_ptr, false);
	logger::debug("Jmping to 0x%.8x", src);
	*self.inst_ptr = src;
}

macro Cpu.inst_ret(&self, Instruction inst)
{
	var src = self._pop(W32);
	logger::debug("Returning to 0x%.8x", src);
	*self.inst_ptr = src;
}


macro Cpu._push(&self, BitWidth $width, val, bool $is_bytes)
{
	*self.stack_ptr -= $width;
	$if $is_bytes:
		self.mem_set(*self.stack_ptr, $width, val);
	$else
		self.mem_get(*self.stack_ptr, $width).set($width, val);
	$endif
}

macro Cpu._pop(&self, BitWidth $width)
{
	var ret = self.mem_get(*self.stack_ptr, $width).get($width);
	*self.stack_ptr += $width;
	return ret;
}

<*
	@require $typeof(val).typeid == $width.type
	@require $stringify(#arg) == "src" || $stringify(#arg) == "dst"
*>
macro Cpu.set_val(&self, BitWidth $width, Instruction inst, #arg, val, bool $zero = false) @safemacro
{
	uint offset = @arg_offset($width, inst, #arg);
	// logger::debug("Current idx is %s, calculated offset is %s", *self.inst_ptr, offset);
	$if !$zero:
		switch (inst.#arg)
		{
			case REG:
				self.regs[self.mem_get(*self.inst_ptr + offset, 1).get(W8)].write($width, val);
			case REG_PTR:
			case IMM:
				abort("%s", inst.#arg);
			case IMM_PTR:
				self.mem_get(self.mem_get(*self.inst_ptr + offset, common::PTR_SIZE).get(W32), $width).set($width, val);
		}
	$else
		$error("$zero not implented yet");
	$endif
}

<*
	@require $stringify(#arg) == "src" || $stringify(#arg) == "dst"
	@ensure $typeof(return).typeid == $width.type
*>
macro Cpu.get_val(&self, BitWidth $width, Instruction inst, #arg) @safemacro
{
	uint offset = @arg_offset($width, inst, #arg);
	// logger::debug("Current idx is %s, calculated offset is %s", *self.inst_ptr, offset);
	switch (inst.#arg)
	{
		case REG:
			return self.regs[self.mem_get(*self.inst_ptr + offset, 1).get(W8)].read($width);
		case REG_PTR:
			return self.mem_get(self.regs[self.mem_get(*self.inst_ptr + offset, 1).get(W8)] + self.mem_get(*self.inst_ptr + 1, 1).get(W8), $width).get($width);
		case IMM:
			return self.mem_get(*self.inst_ptr + offset, $width).get($width);
		case IMM_PTR:
			return self.mem_get(self.mem_get(*self.inst_ptr + offset, common::PTR_SIZE).get(W32), $width).get($width);
	}
}

<*
	@ensure io::printfn("@add returned: %s", return)!! == 0
*>
macro @add(typeid $type, #a, #b) 
{
	var a = @as($typefrom($type), (#a) + (#b));
	logger::debug("@add result: %s", a);
	return a;
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

macro Cpu.read_imm(&self, uint $offset, BitWidth $width, bool $signed = false)
{
	$if $signed:
		return @as($typefrom($width.itype),  self.mem_get(*self.inst_ptr + $offset, $width).get($width));
	$else
		return @as($typefrom($width.itype), self.mem_get(*self.inst_ptr + $offset, $width).get($width));
	$endif
}

<*
 @require @typeis(value, $typefrom($width.type)) ||| @typeis(value, $typefrom($width.itype))
*>
macro void Cpu.write_reg(&self, uint offset, BitWidth $width, value)
{
	self.regs[self.mem_get(*self.inst_ptr + offset, 1).get(W8)].write($width, value);
}

macro Cpu.read_reg(&self, uint offset, BitWidth $width, bool $signed = false)
{
	$if $signed:
		return @as($typefrom($width.itype), self.regs[self.mem_get(*self.inst_ptr + offset, 1).get(W8)].read($width));
	$else
		return @as($typefrom($width.type), self.regs[self.mem_get(*self.inst_ptr + offset, 1).get(W8)].read($width));
	$endif
}

macro Cpu.move_forward(&self, BitWidth $width, InstructionType $type, Instruction inst)
{
	// *self.inst_ptr += $width.size * 2;
	if (inst.has_offset)
	{
		*self.inst_ptr += 2;
	}
	$switch $type.arg_count():
		$case 1:
			*self.inst_ptr += arg_size(inst.src, $width);
		$case 2:
			*self.inst_ptr += arg_size(inst.src, $width);
			*self.inst_ptr += arg_size(inst.dst, $width);
		$case 0:
	$endswitch
}

<*
	FIXME: Does not work if inst.has_offset == true
*>
macro uint arg_size(ArgType type, BitWidth $width)
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

<*
	@require $stringify(#arg) == "src" || $stringify(#arg) == "dst"
*>
macro uint @arg_offset(BitWidth $width, Instruction inst, #arg) => @select($stringify(#arg) == "src", 0, (uint)inst.has_offset + arg_size(inst.src, $width));
