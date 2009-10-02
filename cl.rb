module CL
	class Var
	
	end

	class Filter

	end

	class CalcExp

	end

	class Iterator
	
	end

	class Evaluator

		def initialize vars
			@vars = vars || {}
		end

		def method_missing met, *ars, &bl

		end

	end

end

def CL &blk

end
