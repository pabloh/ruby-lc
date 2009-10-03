begin
	#Fails in 1.9.1
	require 'generator'
rescue 
	Generator = Enumerator
end

module CL
	class Value
		attr_reader :value
		def initialize(val); @value = val ; end
		def to_s; value.to_s ; end
		alias next value # agghh!!!!
	end

	class Var
		attr_accessor :value
		attr_reader :name
		def initialize name, value = 0, step = 1
			@name, @value, @step = name, value, step
		end
		
		def inc
			@value += @step
		end

		def to_s
			name.to_s 
		end

		def << enum
			#TODO: enum must me Enumerable
			Iterator.new(self,enum)	
		end		
	end

	class Filter
		BOPRS = [ :<, :> ,:>=, :<=,  :== , :===, :=~, :&, :|  ]

		UOPRS = [ :~@ ]

		def to_const arrs
			arrs.map {|x| [TrueClass,FalseClass,Numeric].member?(x.class) ? Value.new(x) : x}
		end

		def initialize var1_uopr, opr_uvar, var2 = nil
			@var1, @opr, @var2 =  *to_const(var2 ? [var1_uopr, opr_uvar, var2] : [opr_uvar,var1_uopr])
		end

		def to_s
			"( " + (@var2 ? @var1.to_s + " " + @opr.to_s + " " + @var2.to_s : @opr.to_s + @var1.to_s ) + " )"
		end

		def value
			case @opr
			when :&
				@var1.value && @var2.value
			when :|
				@var1.value || @var2.value
			when :~
				!@var1.value
			else
				@var1.value.send @opr,@var2.value
			end
		end

		alias next value
	end

	True = Filter.new(:~,false)
	False = Filter.new(:~,true)

	Nat = 0..(1.0/0)

	class CalcExpr
		BOPRS = [ :+, :- , :* , :/ , :%, :**, :div, :divmod , :mod  ]

		UOPRS = [ :+@, :-@ ]

		FilterError = "Filter is not allowed inside an expresion"

		def to_const arrs
			arrs.map {|x| x.is_a?(Numeric) ? Value.new(x) : x}
		end
	
		def initialize var1_uopr, opr_uvar, var2 = nil
			raise ArgumentError.new(FilterError) if Filter === var2 
			@var1, @opr, @var2 =  *to_const(var2 ? [var1_uopr, opr_uvar, var2] : [opr_uvar,var1_uopr])
		end

		def to_s
			"( " + (@var2 ? @var1.to_s + " " + @opr.to_s + " " + @var2.to_s : @opr.to_s + @var1.to_s ) + " )"
		end

		def value
			@var1.value.send *(@var2.value ? [@opr,@var2.value]: @opr)
		end

		alias next value
	end
	
	class Iterator
		def initialize var, enum
			@var, @enum = var, enum
		end
		
		def iter iter
			Generator.new do |y|
				@enum.each {|x| @var.value = x; y.yield(iter.next)  }
			end
		end

		def to_s
			@var.to_s + " in " + @enum.to_s
		end
	end

	[CalcExpr, Filter].each do |klass_oper|
		[Var, klass_oper].each do |klass| 
			klass.class_eval do
				klass_oper::BOPRS.each do |opr| 
					define_method(opr) do |param|
						klass_oper.new(self, opr, param)
					end
				end
				klass_oper::UOPRS.each do |opr| 
					define_method(opr) do 
						klass_oper.new(opr,self)
					end
				end
			end
		end
	end

	class Evaluator
		def initialize vars = {}
			@vars = vars
		end

		def method_missing met, *ars, &bl
			@vars[met] ||= Var.new(met) 
		end

		def cl_for arr
			expr = arr.shift
			conds, iters = arr.partition {|c| Filter === c }
			cond = conds.inject(:&) || CL::True
			iter = iters.reverse.inject(expr) {|mem, obj| obj.iter(mem) }
			
			Generator.new do |y|
				iter.each {|x| y.yield(x) if cond.value }
			end
		end
	end

end

def CL &blk
	arr = yield(e = CL::Evaluator.new) 
	e.cl_for arr
end
