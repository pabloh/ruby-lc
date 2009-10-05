begin
  #Fails in 1.9.1
  require 'generator'
rescue 
  Generator = Enumerator
end

module LC
  SingleParameter = false

  #Methods and top-level 'functions' calls inside the lc's block
  def self.func func, *arg
     met Kernel,func, *arg
  end
        
  def self.met rec, met, *args
    (met.to_s =~ /\?$/ ? Filter : CalcExpr).new(Value.new(rec),met,*args)
  end

  class Value
    attr_reader :value
    def initialize(val); @value = val ; end
    def to_s; value.to_s ; end
  end

  class Var
    attr_accessor :value
    attr_reader :name
    def initialize name, value = 0
      @name, @value= name, value
    end

    def inc step = 1
      @value += step
    end

    def to_
      name.to_s 
    end

    def coerce obj
      [Value.new(obj),self] if obj.is_a?(Numeric)
    end

    def << enum
      Iterator.new(self,enum)  
    end    
  end

  class Filter
    BOPRS = [ :<, :> ,:>=, :<=, :== ]

    UOPRS = [] 

    FBOPRS = [:&, :|]

    FBOPRS.each do |met| 
      define_method met do |param|
        raise ArgumentError.new(OperatorError) if !param.is_a?(Filter) 
        Filter.new(self, met, param)
      end
    end
    
    OperatorError = "'&' and '|' only take boolean expresions as parameters"
    
    def ~@
      Filter.new(self, :^, True)
    end

    def to_const arr
      arr.map {|x| [TrueClass,FalseClass,Numeric].detect {|c| x.is_a? c} ? Value.new(x) : x}
    end

    def initialize var1_uopr, opr_uvar, var2 = nil
      @var1, @opr, @var2 =  *to_const(var2 ? [var1_uopr, opr_uvar, var2] : [opr_uvar,var1_uopr])
    end

    def coerce obj
      [Value.new(obj),self] if [TrueClass,FalseClass,Numeric].detect {|c| obj.is_a? c} 
    end

    def to_s
      "( " + (@var2 ? @var1.to_s + " " + @opr.to_s + " " + @var2.to_s : @opr.to_s + @var1.to_s ) + " )"
    end

    def value
      @var1.value.send @opr,*@var2.value
    end
  end

  True = Value.new(true)
  False = Value.new(false)

  Nat = 0..(1.0/0)

  class CalcExpr
    BOPRS = [ :+, :- , :* , :/ , :%, :**, :div, :divmod , :mod  ]

    UOPRS = [ :+@, :-@ ]
    
    def coerce obj
      [Value.new(obj),self] if obj.is_a?(Numeric)
    end

    FilterError = "Filter is not allowed inside an expresion"

    def to_const arr
      arr.map {|x| x.is_a?(Numeric) ? Value.new(x) : x}
    end
  
    def initialize var1_uopr, opr_uvar, var2 = nil
      raise ArgumentError.new(FilterError) if  var2.is_a?(Filter)
      @var1, @opr, @var2 =  *to_const(var2 ? [var1_uopr, opr_uvar, var2] : [opr_uvar,var1_uopr])
    end

    def coerce obj
      [Value.new(obj),self] if obj.is_a?(Numeric)
    end

    def to_
      "( " + (@var2 ? @var1.to_s + " " + @opr.to_s + " " + @var2.to_s : @opr.to_s + @var1.to_s ) + " )"
    end

    def value
      @var1.value.send *(@var2.value ? [@opr,*@var2.value]: @opr)
    end
  end
  
  class Iterator
    #TODO: Configure iter's lambda so it can skip values
    def initialize var, enum, step = 1
      @var, @enum, @step, @pos = var, enum, step, 0
    end
    
    def iter
      lambda { @enum.each {|x| @var.value = x; yield } }
    end

    def to_
      @var.to_s + " in " + @enum.to_
    end
  end

  [[CalcExpr,Var,Value], [Filter,Var,Value,CalcExpr]].each do |klass_oper,*klases|
    (klases << klass_oper).each do |klass|
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
      conds, iters = arr.partition {|c| c.is_a?(Filter) }
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
    #TODO: extract variables name from block parameter 
    #parms = blk.arity.enum_for(:times).zip("a".."zzz").map {|t,v| LC::Var.new v.to_sym }
    parms = blk.arity.enum_for(:times).map { LC::Var.new :unnamed }
    arr = yield(*parms)
  else arr = yield(e) 
  end
  e.lc_for arr
end
