begin
  #Fails in 1.9.1
  require 'generator'
rescue 
  Generator = Enumerator
end

module LC
  SingleParameter = false
  
  class Value
    attr_reader :value
    def initialize(val); @value = val ; end
    def to_s; value.to_s ; end
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

    def coerce obj
      [Value.new(obj),self] if Numeric === obj
    end

    def << enum
      Iterator.new(self,enum)  
    end    
  end

  class Filter
    BOPRS = [ :<, :> ,:>=, :<=,  :== , :===, :=~, :&, :|  ]

    UOPRS = [ :~@ ]

    def to_const arrs
      arrs.map {|x| [TrueClass,FalseClass,Numeric].detect {|c| c === x} ? Value.new(x) : x}
    end

    def initialize var1_uopr, opr_uvar, var2 = nil
      @var1, @opr, @var2 =  *to_const(var2 ? [var1_uopr, opr_uvar, var2] : [opr_uvar,var1_uopr])
    end

    def coerce obj
      [Value.new(obj),self] if Numeric === obj
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
  end

  True = Value.new(true)
  False = Value.new(false)

  Nat = 0..(1.0/0)

  class CalcExpr
    BOPRS = [ :+, :- , :* , :/ , :%, :**, :div, :divmod , :mod  ]

    UOPRS = [ :+@, :-@ ]
    
    def coerce obj
      [Value.new(obj),self] if Numeric === obj
    end

    FilterError = "Filter is not allowed inside an expresion"

    def to_const arrs
      arrs.map {|x| x.is_a?(Numeric) ? Value.new(x) : x}
    end
  
    def initialize var1_uopr, opr_uvar, var2 = nil
      raise ArgumentError.new(FilterError) if Filter === var2 
      @var1, @opr, @var2 =  *to_const(var2 ? [var1_uopr, opr_uvar, var2] : [opr_uvar,var1_uopr])
    end

    def coerce obj
      [Value.new(obj),self] if Numeric === obj
    end

    def to_s
      "( " + (@var2 ? @var1.to_s + " " + @opr.to_s + " " + @var2.to_s : @opr.to_s + @var1.to_s ) + " )"
    end

    def value
      @var1.value.send *(@var2.value ? [@opr,@var2.value]: @opr)
    end
  end
  
  class Iterator
    #TODO: Only one iterator per variable
    def initialize var, enum
      @var, @enum = var, enum
    end
    
    def iter
      lambda { @enum.each {|x| @var.value = x; yield } }
    end

    def to_s
      @var.to_s + " in " + @enum.to_s
    end
  end

  [[CalcExpr,Var,Value], [Filter,Var,Value,CalcExpr]].each do |klases|
    klass_oper = klases.first
    klases.each do |klass|
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

    def lc_for arr
      expr = arr.shift
      conds, iters = arr.partition {|c| Filter === c }
      cond = conds.inject(:&) || LC::True
      Generator.new do |y|
        calc = lambda { y.yield(expr.value) if cond.value }
        iters.reverse.inject(calc) {|mem, obj| obj.iter(&mem) }.call
      end
    end
  end

end

def LC &blk
  e = LC::Evaluator.new
  unless LC::SingleParameter
     #TODO: extract variables name from block parameters
    parms = blk.arity.enum_for(:times).zip("a".."zzz").map {|t,v| LC::Var.new v.to_sym }
    arr = yield(*parms)
  else arr = yield(e) 
  end
  e.lc_for arr
end
