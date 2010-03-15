implement TAP;

include "sys.m";
	sys: Sys;
	sprint: import sys;
include "draw.m";
include "debug.m";
        debug: Debug;
        Prog, Module, Exp: import debug;
include "../../module/tap.m";

have_plan, tests_run: int;
dir, reason: string;

init()
{
	sys = load Sys Sys->PATH;
        debug = load Debug Debug->PATH;
	if(debug != nil)
		debug->init();
}

plan(tests: int)
{
	have_plan = 1;
	out_plan(tests);
}

skip_all(reason: string)
{
	out_skipall(reason);
	exit;
}

bail_out(reason: string)
{
	out_bailout(reason);
	exit;
}

done()
{
	if(!have_plan)
		out_plan(tests_run);
}

diag(msg: string)
{
	out_diag(msg);
}

skip(howmany: int, msg: string)
{
	for(i := 0; i < howmany; i++){
		(tmpdir, tmpreason) := (dir, reason);
		(dir, reason) = ("SKIP", msg);
		out_ok(nil);
		(dir, reason) = (tmpdir, tmpreason);
	}
	raise "SKIP";
}

todo(msg: string)
{
	if(msg == nil)
		(dir, reason) = (nil, nil);
	else
		(dir, reason) = ("TODO", msg);
}

ok(bool:int, msg: string)
{
	if(bool)
		return out_ok(msg);
	return out_not_ok(msg);
}

eq_int(a,b: int, msg: string)
{
	if(a == b)
		return out_ok(msg);
	out_not_ok(msg);
	out_failed(sprint("       got: %d", a));
	out_failed(sprint("  expected: %d", b));
}

ne_int(a,b: int, msg: string)
{
	if(a != b)
		return out_ok(msg);
	out_not_ok(msg);
	out_failed(sprint("  %d", a));
	out_failed("      ne");
	out_failed(sprint("  %d", b));
}

eq(a,b: string, msg: string)
{
	if(a == b)
		return out_ok(msg);
	out_not_ok(msg);
	out_failed(sprint("       got: %#q", a));
	out_failed(sprint("  expected: %#q", b));
}

ne(a,b: string, msg: string)
{
	if(a != b)
		return out_ok(msg);
	out_not_ok(msg);
	out_failed(sprint("  %#q", a));
	out_failed("      ne");
	out_failed(sprint("  %#q", b));
}

eq_list[T](cmp: ref fn(a,b: T): int, a,b: list of T, msg: string)
{
	a = sort(cmp, a);
	b = sort(cmp, b);
	for(; a != nil; (a, b) = (tl a, tl b)){
		if(b == nil)
			return out_not_ok(msg);
		if(cmp(hd a, hd b) != 0)
			return out_not_ok(msg);
	}
	if(b != nil)
		return out_not_ok(msg);
	return out_ok(msg);
}

eq_arr[T](cmp: ref fn(a,b: T): int, a,b: array of T, msg: string)
{
	if(len a != len b)
		return out_not_ok(msg);
	inssort(cmp, a);
	inssort(cmp, b);
	for(i := 0; i < len a; i++)
		if(cmp(a[i], b[i]) != 0)
			return out_not_ok(msg);
	return out_ok(msg);
}

### Internal helpers

l2a[T](l: list of T): array of T # from mjl's util0
{
	a := array[len l] of T;
	i := 0;
	for(; l != nil; l = tl l)
		a[i++] = hd l;
	return a;
}

a2l[T](a: array of T): list of T # from mjl's util0
{
	l: list of T;
	for(i := len a-1; i >= 0; i--)
		l = a[i]::l;
	return l;
}

inssort[T](cmp: ref fn(a, b: T): int, a: array of T) # from mjl's util0
{
	for(i := 1; i < len a; i++) {
		tmp := a[i];
		for(j := i; j > 0 && cmp(a[j-1], tmp) >= 0; j--)
			a[j] = a[j-1];
		a[j] = tmp;
	}
}

sort[T](cmp: ref fn(a, b: T): int, l: list of T): list of T
{
	a := l2a(l);
	inssort(cmp, a);
	return a2l(a);
}

escape(msg: string): string
{
	esc := "";
	for(i := 0; i < len msg; i++)
		case msg[i] {
		'#' =>	esc[len esc] = '\\';
			esc[len esc] = '#';
		'\n' => esc[len esc] = '\n';
			esc[len esc] = '#';
			esc[len esc] = ' ';
		' ' =>	if(len esc < 3 || esc[len esc - 3:] != "\n# ")
				esc[len esc] = ' ';
		* =>	esc[len esc] = msg[i];
		}
	return esc;
}

out_ok(msg: string)
{
	out_test("ok", msg);
}

out_not_ok(msg: string)
{
	out_test("not ok", msg);
	out_failed(sprint("Failed test %#q", escape(msg)));
	out_failed(sprint("in %s", caller()));
}

out_failed(msg: string)
{
	sys->fprint(sys->fildes(2), "#   %s\n", msg);
}

caller(): string
{
	if(debug == nil)
		return "unknown";
	pid := sys->pctl(0, nil);
	spawn getcaller(pid, c := chan of string);
	return <-c;
}

getcaller(pid: int, c: chan of string)
{
	(p, err) := debug->prog(pid);
	if(err != nil){
		c <-= sprint("debug: prog() failed: %s", err);
		exit;
	}
	stk: array of ref Exp;
	(stk, err) = p.stack();
	if(err != nil){
		c <-= sprint("debug: stack() failed: %s", err);
		exit;
	}
	for(i := 0; i < len stk; i++){
		stk[i].m.stdsym();
		s := stk[i].srcstr();
		me := "tap.b:";
		if(s[0:len me] != me){
			c <-= s;
			exit;
		}
	}
	c <-= "debug: unknown";
}

### Protocol

out_plan(tests: int)
{
	sys->print("1..%d\n", tests);
}

out_skipall(msg: string)
{
	sys->print("1..0 # SKIP %s\n", escape(msg));
}

out_bailout(msg: string)
{
	sys->print("Bail out! %s\n", escape(msg));
}

out_diag(msg: string)
{
	sys->print("# %s\n", escape(msg));
}

out_test(result, msg: string)
{
	tests_run++;
	if(msg == nil && dir == nil)
		sys->print("%s %d\n", result, tests_run);
	if(msg != nil && dir == nil)
		sys->print("%s %d - %s\n", result, tests_run, escape(msg));
	if(msg == nil && dir != nil)
		sys->print("%s %d # %s %s\n", result, tests_run, dir, escape(reason));
	if(msg != nil && dir != nil)
		sys->print("%s %d - %s # %s %s\n", result, tests_run, escape(msg), dir, escape(reason));
}
