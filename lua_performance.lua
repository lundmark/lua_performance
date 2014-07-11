local ffi = require "ffi"
local C = ffi.C

require "WinBase"
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
	local function runbenchmark(name, code, count, ob)
		local f = loadstring([[
			local count,ob = ...
			local clock = GetCurrentTickTime
			local start = clock()
			for i=1,count do ]] .. code .. [[ end
			return (clock() - start)*1000
		]])
		io.write(string.format("%6.3f ms\t%s\n", f(count, ob), name))
	end

	local nameof = {}
	local codeof = {}
	local tests  = {}
	function addbenchmark(name, code, ob)
		nameof[ob] = name
		codeof[ob] = code
		tests[#tests+1] = ob
	end
	function clearbenchmarks()
		tests = {}
	end
	function runbenchmarks(count)
		for _,ob in ipairs(tests) do
			runbenchmark(nameof[ob], codeof[ob], count, ob)
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

if jit then
	io.write("JIT OFF\n")
	jit.off()
end
--[[
addbenchmark("Standard (solid)", "ob:test()", makeob1())
addbenchmark("Standard (metatable)", "ob:test()", makeob2())

addbenchmark("Object using closures (PiL 16.4)", "ob.test()", makeob3())
addbenchmark("Object using closures (noself)", "ob.test()", makeob4())

addbenchmark("Direct Access", "ob.data = ob.data + 1", makeob1())

addbenchmark("Local Variable", "ob = ob + 1", 0)]]

addbenchmark("Local Function Call (no args)", "ob()", make_func_noargs())
addbenchmark("Local Function Call (no args), 3 args", "ob(1, 2, 3)", make_func_noargs())
addbenchmark("Local Function Call (no args), 10 args", "ob(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)", make_func_noargs())
addbenchmark("Local Function Call (3 args), 0 args", "ob()", make_func_3args())
addbenchmark("Local Function Call (3 args), 3 args", "ob(1, 2, 3)", make_func_3args())
addbenchmark("Local Function Call (3 args), 10 args", "ob(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)", make_func_3args())

addbenchmark("Local Function Call (10 args), 0 args", "ob()", make_func_10args())
addbenchmark("Local Function Call (10 args), 3 args", "ob(1, 2, 3)", make_func_10args())
addbenchmark("Local Function Call (10 args), 10 args", "ob(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)", make_func_10args())
runbenchmarks(select(1,...) or 10000000)
clearbenchmarks()
addbenchmark("ipairs() 100 iterations", "for i, value in ipairs(ob) do end", make_100_numbered_table())
addbenchmark("pairs() 100 iterations", "for i, value in pairs(ob) do end", make_100_numbered_table())
runbenchmarks(100000)