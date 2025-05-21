module logger;
import std::io;
import std::math::random;

macro debug(String msg, ...)
{
  $if $feature(DEBUG):
    // io::eprintf("[DEBUG] (%s:%s %s) ", $$FILE, $$LINE, $$FUNC);
	io::eprintf("[DEBUG] ");
    io::eprintfn(msg, $vasplat);
  $endif
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
