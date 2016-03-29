require 'ruby-prof'
require 'byebug'
require 'pry-byebug'
TARGET = [1,2,3,8,0,4,7,6,5]
COUNT = 9
NEIGHBORS = [[1, 3],
             [0, 2, 4],
             [1, 5],
             [0, 4, 6],
             [1, 3, 5, 7],
             [2, 4, 8],
             [3, 7],
             [8, 6, 4],
             [7, 5]]
def get_reversal(numbers)
  numbers = numbers.dup
  numbers.delete 0
  r = 0
  loop do
    break if numbers == (1..8).to_a
    changed = false
    numbers.count.times do |i|
      ((i+1)...numbers.count).each do |j|
        if numbers[i] > numbers[j]
          numbers[i], numbers[j] = numbers[j], numbers[i]
          r += 1
          changed = true
          break
        end
      end
      break if changed
    end
  end
  r % 2
end

class State
  include Comparable
  attr_accessor :parent, :numbers
  def initialize(parent, new_pos = nil)
    if new_pos
      self.parent = parent
      @numbers = self.parent.numbers.dup
      # swap
      @numbers[@numbers.index(0)], @numbers[new_pos] =
          @numbers[new_pos], @numbers[@numbers.index(0)]
    else
      @numbers = parent # the first element
      self.parent = nil
    end
  end
  def ==(other)
    self.numbers == other.numbers
  end
  def <=>(other)
    self.func_f <=> other.func_f
  end

  def func_f
    self.func_g + self.func_h
  end
  def func_g
    @g || (@g = (self.parent ? self.parent.func_g : 0) + 1)
  end
  def func_h
    # h的含义是9-已经放到该放的位置的元素个数
    unless @h
      @h = COUNT
      COUNT.times do |x|
        @h -= 1 if TARGET[x] == self.numbers[x]
      end
    end
    @h
  end
  def neighbors
    ret = []
    NEIGHBORS[self.numbers.index(0)].each do |p|
      ret << State.new(self, p)
    end
    ret
  end
  def target?
    COUNT.times do |x|
      return false unless TARGET[x] == self.numbers[x]
    end
    true
  end
end

class NaivePriorityQueue
  def initialize
    @elements = []
  end

  def method_missing(method_name, *args, &block)
    @elements.send(method_name, *args, &block)
  end

  def pop
    @elements.sort!
    @elements.delete_at(0)
  end
end

raise 'Wrong argument' unless ARGV.size == 2

infile, outfile = ARGV
numbers = File.read(infile).split.map(&:to_i)
if get_reversal(numbers) != get_reversal(TARGET)
  puts 'no solution'
  exit
end

s = State.new(numbers)
open = NaivePriorityQueue.new
open << s
closed = []

counter = 0

result = loop do
  v = open.pop # O(nlogn)
  unless v
    puts 'no result'
    exit
  end
  closed << v
  break v if v.target?

  v.neighbors.each do |neighbor|
    next if closed.include? neighbor # O(n)
    open_index = open.index(neighbor)
    if open_index # O(n)
      if open[open_index].func_g > neighbor.func_g
        open[open_index] = neighbor
      end
    else
      open << neighbor
    end
  end
end

final = []
node = result
while node do
  final.insert(0, node.numbers)
  node = node.parent
end
final.delete_at(0)
str = "#{final.count}\n\n"
final.each do |status|
  i = 0
  3.times do
    3.times do
      str += "#{status[i]} "
      i += 1
    end
    str += "\n"
  end
  str += "\n"
end

puts str

File.write(outfile, str)