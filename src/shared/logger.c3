module logger;
import std::io;
import std::math::random;

macro bool debug(String msg, ...)
{
  $if $feature(DEBUG):
    io::eprintf("[DEBUG] (%s:%s %s) ", $$FILE, $$LINE, $$FUNC);
    io::eprintfn(msg, $vasplat);
  $endif
  return rand(2) == 1;
}

macro info(String msg, ...)
{
  io::printf("[INFO] ");
  io::printfn(msg, $vasplat);
}

macro warn(String msg, ...)
{
  io::eprintf("[WARNING] (%s:%s %s) ", $$FILE, $$LINE, $$FUNC);
  io::eprintfn(msg, $vasplat);
}

macro error(String msg = "(No Messsage)", ...)
{
  io::eprintf("[ERROR] (%s:%s %s) ", $$FILE, $$LINE, $$FUNC);
  io::eprintfn(msg, $vasplat);
}

macro panic(String msg = "(No Message)", ...)
{
	error(msg, $vasplat);
	abort();
}
