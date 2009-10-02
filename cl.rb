begin
	#Fails in 1.9.1
	require 'generator'
rescue 
	Generator = Enumerator
end

module CL

	class Var
		attr_accessor :value
	  def initialize value
			@value = value
		end	
	end

	class Filter
		BOPRS = [ :<, :> ,:>=, :<=,  :== , :===, :=~  ]

		#TODO: unary operators
	end

	Nat = 0..(1.0/0)

	class CalcExpr
		BOPRS = [ :+, :- , :* , :/ , :%, :**, :div, :divmod , :mod  ]

		#TODO: unary operators
	end
	
	class Iterator
	
	end

	[Var, CalcExpr].each do |klass| 
		CalcExpr::BOPRS.each do |opr| 
			klass.class_eval do
				define_method(opr) do |param|
					#TODO: param must be a number or another var/exp
					CalcExpr.new(self, opr, param)
				end
			end
		end
	end

	[Var, Filter].each do |klass| 
		Filter::BOPRS.each do |opr| 
			klass.class_eval do
				define_method(opr) do |param|
					#TODO: param must be a number or another var/exp/filter
					Filter.new(self, opr, param)
				end
			end
		end
	end

	class Evaluator
		def initialize vars
			@vars = vars || {}
		end

		def method_missing met, *ars, &bl
				var = @vars[met] ||= Var.new(met) 
				#Do some stuff...
				var
		end
	end

end

def CL &blk
	arr = yield Evaluator.new 

end
