module logger;
import std::io;

macro debug(String msg, ...)
{
  $if $feature(DEBUG):
    io::eprintf("[DEBUG] (%s:%s %s) ", $$FILE, $$LINE, $$FUNC);
    io::eprintfn(msg, $vasplat);
  $endif
}

macro info(String msg, ...)
{
  io::printf("[INFO] (%s:%s %s) ", $$FILE, $$LINE, $$FUNC);
  io::printfn(msg, $vasplat);
}

macro warn(String msg, ...)
{
  io::eprintf("[WARNING] (%s:%s %s) ", $$FILE, $$LINE, $$FUNC);
  io::eprintfn(msg, $vasplat);
}

macro error(String msg, ...)
{
  io::eprintf("[ERROR] (%s:%s %s) ", $$FILE, $$LINE, $$FUNC);
  io::eprintfn(msg, $vasplat);
  unreachable();
}
