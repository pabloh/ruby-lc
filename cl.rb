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
	end

	class Var
		attr_reader :value, :name
		def initialize name, value = 0, step = 1
			@name, @value = name, value, step
		end
		
		def inc
			@value += @step
		end

		def << enum
			#TODO: enum must me Enumerable
			Iterator.new(self,enum)	
		end		
	end

	class Filter
		BOPRS = [ :<, :> ,:>=, :<=,  :== , :===, :=~  ]

		UOPRS = [ :~@ ]
	end

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

		def value
			@var1.value.send *(@var2.value ? [@opr,@var2.value]: @opr)
		end
	end
	
	class Iterator
	
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
				var = @vars[met] ||= Var.new(met) 
				#Do some stuff...
				var
		end

		def generator_for exp

		end
	end
end

def CL &blk
	arr = yield Evaluator.new 

end
