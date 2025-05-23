module emulator;
import common;
import logger;

import std::io;
import std::thread;
import std::time;
import std::collections::list;

alias alloc = allocator::mem;

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

bitstruct CpuFlags : char
{
	bool zero : 0;
	bool carry : 1;
	bool interrupt : 3;
	bool exception_sp : 2;
}

struct Cpu
{
	// The address of the current instruction in memory
	Register* loop_ptr; // A pointer to regs[31];
	Register* stack_ptr; // A pointer to regs[32];
	Register* exception_ptr; // A pointer to regs[33];
	Register* frame_ptr; // A pointer to regs[34];
	Register* inst_ptr; // a pointer to regs[35];
	Register inst_ptr_next;
	CpuFlags flags;
	bool mmu_enabled;
	bool page_directory;
	Register[common::NUM_REGISTERS] regs;
}

<*
	@require len == buf.len
*>
fn void Cpu.mem_set(&self, uint start, uint len, char[] buf) @inline
{
	//if (!self.mmu_enabled)
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
	//if (!self.mmu_enabled)
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
	self.loop_ptr = &self.regs[31];
	self.stack_ptr = &self.regs[32];
	self.exception_ptr = &self.regs[33];
	self.frame_ptr = &self.regs[34];
	self.inst_ptr = &self.regs[35];
	*self.inst_ptr = common::DEFAULT_INST_PTR;
	*self.stack_ptr = common::DEFAULT_STACK_PTR;
	self.inst_ptr_next = *self.inst_ptr;
	self.mmu_enabled = true;
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

	logger::debug("Executing (%s b): %h", prog.len, prog[:prog.len < 200 ? prog.len : 200]);

	bool running = true;


	$if $feature(PERF):
		uint iteration = 0;
		Clock clock = clock::now();
	$endif

	Instruction inst;
//	while (running)
	{
		switch (inst::GET_) @jump
		{
			case inst::NOP:
				logger::panic("Reached NOP (does not exist in fox32rom)");
				nextcase;
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
				*cpu.inst_ptr = cpu.inst_ptr_next;

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
				
				inst = (Instruction)cpu.mem_get(*cpu.inst_ptr, 2).get(W16);

				logger::debug("%s 0x%.8x -> %s", iters, *cpu.inst_ptr, inst);

				// Point at the next byte
				cpu.inst_ptr_next = *cpu.inst_ptr + common::INST_SIZE;

				$if $feature(DEBUG):
					@each_width(inst.width; BitWidth $width)
					{
						uint tmp = cpu.inst_ptr_next;
						$for var $type = 0; $type < char.max; $type++:
							$if inst::is_valid_instruction($type):
								if (inst.type == $type)
								{
									cpu.move_forward($width, $type, inst);
									logger::debug("Next instruction at %.8x : %s", cpu.inst_ptr_next, (Instruction)cpu.mem_get(cpu.inst_ptr_next, 2).get(W16));
								}
							$endif
						$endfor
						cpu.inst_ptr_next = tmp;
					};
				$endif

				// Execute the current instruction
				nextcase inst.type;
			case inst::HALT:
			case inst::BREAK:
				logger::info("Exiting after %s clock cycles", iters);
				foreach (i, reg : cpu.regs)
				{
					logger::info("%s: %.8x", common::REG_NAMES[i], reg);
				}
				return 0;

			case inst::INC:
				cpu.inst_inc(inst);
				nextcase inst::GET;
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
				cpu.mmu_enabled = false;
				nextcase inst::GET;
			case inst::MSE:
				cpu.mmu_enabled = true;
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
				logger::error("Interrupts don't work yet :3");
				nextcase inst::GET;
			case inst::ICL:
				cpu.flags.interrupt = false;
				nextcase inst::GET;
			case inst::LOOP:
				cpu.inst_loop(inst);
				nextcase inst::GET;
			case inst::PUSH:
				cpu.inst_push(inst);
				nextcase inst::GET;
			case inst::POP:
				cpu.inst_pop(inst);
				nextcase inst::GET;
			case inst::SLA:
				cpu.inst_sla(inst);
				nextcase inst::GET;
			default:
				logger::error("Instruction %s is not implemented yet", inst.type.get_name());
				nextcase inst::BREAK;
		}
	}
	$if $feature(PERF):
		NanoDuration nano_seconds = clock.mark(); 
		io::printfn("Took %s or %s ns to do %s iterations, %dMhz", nano_seconds, @as(long, nano_seconds), iteration, (@as(double, iteration) /	nano_seconds.to_sec() / 1000000).round() );
	$endif

	return 0;
}

// NOTE: #src and #dst are FUNCTIONS that will be called EVERY TIME they are used
fn void Cpu.inst_inc(&self, Instruction inst) @inline => self.@setup_w(inst; BitWidth $width, #src, #dst)
{
	logger::debug("Incrementing %s", #src);
	self.set_val($width, inst, SRC, @as($typefrom($width.type), #src + 1));
}

fn void Cpu.inst_add(&self, Instruction inst) @inline => self.@setup_w(inst; BitWidth $width, #src, #dst)
{
	logger::debug("Adding %s and %s", #dst, #src);
	self.set_val($width, inst, DST, @as($typefrom($width.type), #dst + #src));
}

fn void Cpu.inst_sub(&self, Instruction inst) @inline => self.@setup_w(inst; BitWidth $width, #src, #dst)
{
	logger::debug("Subtracting %s and %s", #dst, #src);
	self.set_val($width, inst, DST, @as($typefrom($width.type), #dst - #src));
}

fn void Cpu.inst_mul(&self, Instruction inst) @inline => self.@setup_w(inst; BitWidth $width, #src, #dst)
{
	logger::debug("multiplying %s and %s", #dst, #src);
	self.set_val($width, inst, DST, @as($typefrom($width.type), #dst * #src));
}

fn void Cpu.inst_div(&self, Instruction inst) @inline => self.@setup_w(inst; BitWidth $width, #src, #dst)
{
	logger::debug("dividing %s by %s", #dst, #src);
	self.set_val($width, inst, DST, @as($typefrom($width.type), #dst / #src));
}

fn void Cpu.inst_mov(&self, Instruction inst) @inline => self.@setup_w(inst; BitWidth $width, #src, #dst)
{
	logger::debug("Moving %s", #src);
	self.set_val($width, inst, DST, #src);
}

fn void Cpu.inst_cmp(&self, Instruction inst) @inline => self.@setup_w(inst; BitWidth $width, #src, #dst)
{
	logger::debug("Comparing %s and %s", #src, #dst);
	$typefrom($width.type) src = #src;
	$typefrom($width.type) dst = #dst;
	self.flags.zero = src == dst;
	self.flags.carry = src > dst;
}

fn void Cpu.inst_jmp(&self, Instruction inst) @inline => self.@setup(inst, W32, false; #src, #dst)
{
	logger::debug("Jmping to 0x%.8x", #src);
	self.inst_ptr_next = #src;
}

fn void Cpu.inst_rjmp(&self, Instruction inst) @inline => self.@setup_w(inst, false; BitWidth $width, #src, #dst)
{
	logger::debug("Jmping by %s", (int)#src);
	self.inst_ptr_next += (int)#src - common::INST_SIZE;
}

extern fn CInt putchar(CInt c);

fn void Cpu.inst_out(&self, Instruction inst) @inline => self.@setup_w(inst; BitWidth $width, #src, #dst)
{
	$typefrom($width.type) dst = #dst;

	if (dst != 0)
	{
		logger::warn("Out to not stdout is not supported yet: 0x%.8x", dst);
	}
	else
	{
		putchar((CInt)#src) @inline;
	}
}

fn void Cpu.inst_call(&self, Instruction inst) @inline => self.@setup(inst, W32, false; #src, #dst)
{
	// save the value before moving forward so I can push the right value and jmp to the right value
	uint src = #src;
	self.move_forward(W32, inst::CALL, inst);
	self._push(W32, self.inst_ptr_next, false);
	logger::debug("Calling 0x%.8x", src);
	self.inst_ptr_next = src;
}

fn void Cpu.inst_ret(&self, Instruction inst) @inline => self.@setup(inst, W32, false; #src, #dst)
{
	$typefrom(BitWidth.W32.type) src = self._pop(W32);
	logger::debug("Returning to 0x%.8x", src);
	self.inst_ptr_next = src;
}

fn void Cpu.inst_loop(&self, Instruction inst) @inline => self.@setup(inst, W32, false; #src, #dst)
{
	if ((*self.loop_ptr -= 1) != 0)
	{
		logger::debug("Looping to 0x%.8x", #src);
		self.inst_ptr_next = #src;
	}
	else
	{
		logger::debug("Not looping");
		self.move_forward(W32, inst::LOOP, inst);
	}
}

fn void Cpu.inst_push(&self, Instruction inst) @inline => self.@setup_w(inst; BitWidth $width, #src, #dst)
{
	logger::debug("Pushing %s %.8x", #src, #src);
	self._push($width, #src, false);
}

// TODO: I don't know if set_val(src) is correct, I should check it
fn void Cpu.inst_pop(&self, Instruction inst) @inline => self.@setup_w(inst; BitWidth $width, #src, #dst)
{
	logger::debug("Popping into %s", #src);
	self.set_val($width, inst, SRC, self._pop($width));
}

fn void Cpu.inst_sla(&self, Instruction inst) @inline => self.@setup_w(inst; BitWidth $width, #src, #dst)
{
	// bit manipulation instructions always have W8 src bc 255 > 32bits
	$typefrom($width.type) res = #dst << #src;
	self.set_val($width, inst, DST, res);
	self.flags.zero = res == 0;
}


macro bool Cpu.should_execute(&self, Instruction inst)
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

macro Cpu.@setup_w(&self, Instruction inst, bool $move = true; @body(BitWidth $width, #src, #dst))
{
	@each_width(inst.width; BitWidth $width)
	{
		self.@setup(inst, $width, $move; #src, #dst)
		{
			@body($width, #src, #dst);
		};
	};
}

macro Cpu.@setup(&self, Instruction inst, BitWidth $width, bool $move = true; @body(#src, #dst))
{
	InstructionType $type = $eval("inst::" +++ @str_upper($$FUNC[9..]));
	if (self.should_execute(inst))
	{
		self.@args(inst, $type, $width; #src, #dst)
		{
			@body(#src, #dst);
		};
	}
	else
	{
		$if !$move:
			self.move_forward($width, $type, inst);
		$endif
		logger::debug("Skipping instruction %s", inst);
	}
	$if $move:
		self.move_forward($width, $type, inst);
	$endif
}

macro Cpu.@args(&self, Instruction inst, InstructionType $type, BitWidth $width; @body(#src, #dst))
{
	$switch $type.arg_count():
		$case 0:
			@body(no_params($type, SRC), @no_param($type, DST));
		$case 1:
			// $typefrom($width.type) src = self.get_val($width, inst, SRC);
			// @body(src, no_param($type, DST));
			@body(self.get_val($width, inst, SRC), no_param($type, DST));
		$case 2:
			$if $type.is_bit_op():
				$typefrom($width.type) src = self.get_val(W8, inst, SRC);
				// @body(self.get_val(W8, inst, SRC), self.get_val($width, inst, DST));
			$else
				$typefrom($width.type) src = self.get_val($width, inst, SRC);
				// @body(self.get_val($width, inst, SRC), self.get_val($width, inst, DST));
			$endif
			$typefrom($width.type) dst = self.get_val($width, inst, DST);
			@body(src, dst);
		$default:
			$error("What");
	$endswitch
}

// only to be used in the above Cpu.@args
macro no_param(InstructionType $type, ArgPos $pos) { $error("Instruction " +++ $type.get_name() +++ " does not have parameter " +++ $pos.name); }

<*
	@require $typeof(val).typeid == $width.type
*>
macro Cpu.set_val(&self, BitWidth $width, Instruction inst, ArgPos $arg, val, bool $zero = false)
{
	uint offset = @arg_offset($width, inst, $arg);
	// logger::debug("Current idx is %s, calculated offset is %s", self.inst_ptr_next, offset);
	$if !$zero:
		switch (inst.$eval($arg.name))
		{
			case REG:
				self.regs[self.mem_get(self.inst_ptr_next + offset, 1).get(W8)].write($width, val);
			case REG_PTR:
				self.mem_get(self.regs[self.mem_get(self.inst_ptr_next + offset, 1).get(W8)], $width).set($width, val);
			case IMM:
				abort("mov into immediate value not implemented");
			case IMM_PTR:
				self.mem_get(self.mem_get(self.inst_ptr_next + offset, common::PTR_SIZE).get(W32), $width).set($width, val);
		}
	$else
		$error("$zero not implented yet");
	$endif
}

<*
	@ensure $typeof(return).typeid == $width.type
*>
macro Cpu.get_val(&self, BitWidth $width, Instruction inst, ArgPos $arg)
{
	uint offset = @arg_offset($width, inst, $arg);
	// logger::debug("Current idx is %s, calculated offset is %s", self.inst_ptr_next, offset);
	switch (inst.$eval($arg.name))
	{
		case REG:
			logger::debug("Reading from register %s", common::REG_NAMES[self.mem_get(self.inst_ptr_next + offset, 1).get(W8)]);
			return self.regs[self.mem_get(self.inst_ptr_next + offset, 1).get(W8)].read($width);
		case REG_PTR:
			return self.mem_get(self.regs[self.mem_get(self.inst_ptr_next + offset, 1).get(W8)] + self.mem_get(self.inst_ptr_next + 1, 1).get(W8), $width).get($width);
		case IMM:
			return self.mem_get(self.inst_ptr_next + offset, $width).get($width);
		case IMM_PTR:
			return self.mem_get(self.mem_get(self.inst_ptr_next + offset, common::PTR_SIZE).get(W32), $width).get($width);
	}
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

macro Cpu.move_forward(&self, BitWidth $width, InstructionType $type, Instruction inst)
{
	// *self.inst_ptr += $width.size * 2;
	if (inst.has_offset)
	{
		self.inst_ptr_next += 2;
	}
	$switch $type.arg_count():
		$case 1:
			self.inst_ptr_next += arg_size(inst.src, $width);
		$case 2:
			$if $type.is_bit_op():
				self.inst_ptr_next += BitWidth.W8;
			$else
				self.inst_ptr_next += arg_size(inst.src, $width);
			$endif
			self.inst_ptr_next += arg_size(inst.dst, $width);
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

macro uint @arg_offset(BitWidth $width, Instruction inst, ArgPos $arg) => @select($arg == SRC, 0, (uint)inst.has_offset + arg_size(inst.src, $width));

enum ArgPos : (String name)
{
	SRC = "src",
	DST = "dst",
}
