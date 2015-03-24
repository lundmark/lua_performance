local ffi = require "ffi"
local C = ffi.C

dofile "WinBase.lua"
local kernel32 = ffi.load("kernel32")

ffi.cdef[[

BOOL QueryPerformanceFrequency(int64_t *lpFrequency);
BOOL QueryPerformanceCounter(int64_t *lpPerformanceCount);
]]


function GetPerformanceFrequency(anum)
	anum = anum or ffi.new("int64_t[1]");
	local success = ffi.C.QueryPerformanceFrequency(anum)
	if success == 0 then
		return nil
	end

	return tonumber(anum[0])
end

function GetPerformanceCounter(anum)
	anum = anum or ffi.new("int64_t[1]")
	local success = ffi.C.QueryPerformanceCounter(anum)
	if success == 0 then
		return nil
	end

	return tonumber(anum[0])
end

function GetCurrentTickTime()
	local frequency = 1/GetPerformanceFrequency();
	local currentCount = GetPerformanceCounter();
	local seconds = currentCount * frequency;
--print(string.format("win_kernel32 - GetCurrentTickTime() - %d\n", seconds));

	return seconds;
end

-- Benchmarking support.
do
	local function runbenchmark(name, code, count, ob, pre_code)
		local code = [[
			local math_floor = math.floor
			local function as_int(v) return v - (v%1) end
			local function is_int(v) return v%1 == 0 end
		]]

		if pre_code then
			code = code .. pre_code
		end

		code = code .. [[
			local count,ob = ...
			local clock = GetCurrentTickTime
			local start = clock()
			for i=1,count do ]] .. code .. [[ end
			return (clock() - start)*1000
		]]
		local f, msg = loadstring(code)
		if not f then
			io.write(string.format("Failed to load test %q:\n%s", name, msg))
		else
			io.write(string.format("%6.3f ms\t%s\n", f(count, ob), name))
		end
	end

	local nameof = {}
	local codeof = {}
	local tests  = {}
	local precodeof = {}
	function addbenchmark(name, code, ob, precode)
		nameof[ob] = name
		codeof[ob] = code
		tests[#tests+1] = ob
		precodeof[ob] = precode
	end
	function clearbenchmarks()
		tests = {}
	end
	function runbenchmarks(count)
		for _,ob in ipairs(tests) do
			runbenchmark(nameof[ob], codeof[ob], count, ob, precodeof[ob])
		end
	end
end

function makeob1()
  local self = {data = 0}
  function self:test()  self.data = self.data + 1  end
  return self
end

local ob2mt = {}
ob2mt.__index = ob2mt
function ob2mt:test()  self.data = self.data + 1  end
function makeob2()
  return setmetatable({data = 0}, ob2mt)
end

function makeob3()
  local self = {data = 0};
  function self.test()  self.data = self.data + 1 end
  return self
end

function makeob4()
  local public = {}
  local data = 0
  function public.test()  data = data + 1 end
  function public.getdata()  return data end
  function public.setdata(d)  data = d end
  return public
end

function make_func_noargs() return function() end end
function make_func_3args() return function(a, b, c) end end
function make_func_10args() return function(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10) end end
function make_100_numbered_table()
	local a = {}
	for i = 1, 100 do a[i] = i end
	return a
end
function iterate_pairs(tab)
	for k, v in pairs(tab) do
	end
end

if jit then
	io.write("JIT OFF\n")
	jit.off()
end

addbenchmark("Standard (solid)", "ob:test()", makeob1())
addbenchmark("Standard (metatable)", "ob:test()", makeob2())

addbenchmark("Object using closures (PiL 16.4)", "ob.test()", makeob3())
addbenchmark("Object using closures (noself)", "ob.test()", makeob4())

addbenchmark("Direct Access", "ob.data = ob.data + 1", makeob1())

addbenchmark("Local Variable", "ob = ob + 1", 0)


addbenchmark("Local Function Call (no args)", "ob()", make_func_noargs())
addbenchmark("Local Function Call (no args), 3 args", "ob(1, 2, 3)", make_func_noargs())
addbenchmark("Local Function Call (no args), 10 args", "ob(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)", make_func_noargs())
addbenchmark("Local Function Call (3 args), 0 args", "ob()", make_func_3args())
addbenchmark("Local Function Call (3 args), 3 args", "ob(1, 2, 3)", make_func_3args())
addbenchmark("Local Function Call (3 args), 10 args", "ob(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)", make_func_3args())

addbenchmark("Local Function Call (10 args), 0 args", "ob()", make_func_10args())
addbenchmark("Local Function Call (10 args), 3 args", "ob(1, 2, 3)", make_func_10args())
addbenchmark("Local Function Call (10 args), 10 args", "ob(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)", make_func_10args())

addbenchmark("5-muls", "local ola = 7; local b = ola * ola * ola * ola * ola", make_func_noargs())
addbenchmark("5-muls-as-exponent", "local ola = 7; local b = ola ^ 5", make_func_noargs())
addbenchmark("5-unpack-noargs", "my_varargs_function5(unpack(five_array))", make_func_noargs(),
[[
local function my_varargs_function5(a1, a2, a3, a4, a5) return a1+a2+a3+a4+a5 end
local five_array = { 1, 2, 3, 4, 5 }
]])

addbenchmark("5-unpack-args", "my_varargs_function5(unpack(five_array, 1, 5))", make_func_noargs(),
[[
local function my_varargs_function5(a1, a2, a3, a4, a5) return a1+a2+a3+a4+a5 end
local five_array = { 1, 2, 3, 4, 5 }
]])

addbenchmark("5-args-array-access", "my_varargs_function5(five_array[1], five_array[2], five_array[3], five_array[4], five_array[5]))", make_func_noargs(),
[[
local function my_varargs_function5(a1, a2, a3, a4, a5) return a1+a2+a3+a4+a5 end
local five_array = { 1, 2, 3, 4, 5 }
]])

addbenchmark("% as is_int", "local value = 3.5; local is_int = value % 1 == 0", make_func_noargs())
addbenchmark("func % as is_int", "local value = 3.5; local is_value_int = is_int(value)", make_func_noargs())
addbenchmark("math.floor as is_int", "local value = 3.6; local is_int = math.floor(value) == value", make_func_noargs())
addbenchmark("math_floor as is_int", "local value = 3.6; local is_int = math_floor(value) == value", make_func_noargs())
addbenchmark("% as to_int", "local value = 3.5; local value_as_int = value - (value % 1)", make_func_noargs())
addbenchmark("func % as to_int", "local value = 3.5; local value_as_int = as_int(value)", make_func_noargs())
addbenchmark("math_floor as to_int", "local value = 3.5; local value_as_int = math_floor(value)", make_func_noargs())
addbenchmark("mul vs div: mul", "local value = 7; local result = value * 0.5", make_func_noargs())
addbenchmark("mul vs div: div", "local value = 7; local result = value / 2", make_func_noargs())
runbenchmarks(select(1,...) or 10000000)
clearbenchmarks()
-- Lower amount of tests:
addbenchmark("100 loops % as is_int", "for i = 1, 100 do local value = 3.5; local is_int = value % 1 == 0 end", make_func_noargs())
addbenchmark("100 loops math_floor as is_int", "local math_floor = math.floor; for i = 1, 100 do local value = 3.6; local is_int = math_floor(value) == value end", make_func_noargs())
addbenchmark("ipairs() 100 iterations", "for i, value in ipairs(ob) do end", make_100_numbered_table())
addbenchmark("pairs() 100 iterations", "for i, value in pairs(ob) do end", make_100_numbered_table())
addbenchmark("for i = 1, n do with count, 100 it", "local n = #ob;for i = 1, n do local a = ob[i] end", make_100_numbered_table())
addbenchmark("call-func-in-for pairs, 100 it", [[
local function a(b)
end
for i, value in pairs(ob) do
	a(value)
end]],
make_100_numbered_table())

addbenchmark("call-func-with-for pairs, 100 it & local created function", [[
local function a(arr)
	for i, value in pairs(arr) do
	end
end
a(ob)]],
make_100_numbered_table())
addbenchmark("call-func-with-for pairs, 100 it & global created function", "iterate_pairs(ob)", make_100_numbered_table())

runbenchmarks(100000)