# MAX_GENERATIONS = 5000
# POPULATION_SIZE = 100
# CROSS_RATE = 0.4
# MUTANT_RATE = 0.01

infile, outfile,
    @max_generations, @population_size,
    @cross_rate, @mutant_rate = ARGV
@max_generations = @max_generations.to_f
@population_size = @population_size.to_f
@cross_rate = @cross_rate.to_f
@mutant_rate = @mutant_rate.to_f

class RouletteRandom
  def initialize(probabilities)
    @probabilities = probabilities
    @total = probabilities.reduce(&:+)
  end

  def rand
    r = Random.rand(0..@total)
    sum = 0
    @probabilities.each_with_index do |p, index|
      sum += p
      return index if sum >= r
    end
    -1
  end
end

class FastRouletteRandom
  def initialize(probabilities)
    @probabilities = []
    probabilities.each_with_index do |p, i|
      @probabilities << [p, i]
    end
    @total = probabilities.reduce(&:+)
    @root = [nil, [0, @total], @probabilities, 0, nil, nil]
    build_tree(@root)
  end

  def rand
    r = Random.rand(0..@total)
    _parent, _range, data, _mid, _left, _right = get_node(@root, r)
    data.first.last
  end
  private

  # node = [parent, range, data, mid, left, right]
  # data is only for leaf nodes
  def build_tree(node)
    _parent, range, data = node
    if data.size == 1
      return
    end

    head, cons = data[0...(data.size/2)], data[(data.size/2)..-1]
    mid = range.min + head.reduce(0) { |sum, item| sum + item.first }
    node[3] = mid
    left_range = [range.min, mid]
    right_range = [mid, range.max]

    left = [node, left_range, head]
    build_tree(left)

    right = [node, right_range, cons]
    build_tree(right)

    node[4] = left
    node[5] = right
  end
  def get_node(node, x)
    _parent, range, data, mid, left, right = node
    if data.size == 1
      return node
    end

    if x < mid
      get_node(left, x)
    else
      get_node(right, x)
    end
  end
end

@cities = (File.read infile).split("\n")[1..-1]
@cities.map! do |city|
  name, x, y = city.split
  [name, x.to_f, y.to_f]
end

def distance(city_a, city_b)
  Math.sqrt((city_a[1] - city_b[1]) ** 2 + (city_a[2] - city_b[2]) ** 2)
end
def trip_distance(path)
  path = path.dup
  len = path.size
  path << path.first
  d = 0.0
  len.times do |i|
    index_a = path[i]
    index_b = path[i+1]
    d += distance(@cities[index_a], @cities[index_b])
  end
  d
end

def fitness(path)
  1.0 / trip_distance(path)
end

def cross_1(a, b)
  new_a = a.dup
  new_b = b.dup

  i = Random.rand(0...(a.size))
  j = (i + Random.rand(1...(a.size))) % a.size

  a_indexes = a[i..j]
  b_indexes = b[i..j]

  selected_items = []

  a_indexes.each do |x|
    selected_items << b[x]
  end
  selected_items.shuffle!
  a_indexes.each do |x|
    new_b[x] = selected_items.pop
  end

  b_indexes.each do |x|
    selected_items << a[x]
  end
  selected_items.shuffle!
  b_indexes.each do |x|
    new_a[x] = selected_items.pop
  end

  [new_a, new_b]
end
def cross_rotate(a, b)
  new_a = a.dup
  new_b = b.dup

  selected_numbers = a.sample(Random.rand(1...a.size))

  b_indexes = Array.new(selected_numbers.size) do |i|
    b.index(selected_numbers[i])
  end

  b_indexes.each_with_index do |bi, index|
    new_b[bi] = selected_numbers[index]
  end

  selected_numbers = b.sample(Random.rand(1...a.size))
  a_indexes = Array.new(selected_numbers.size) do |i|
    a.index(selected_numbers[i])
  end
  a_indexes.each_with_index do |ai, index|
    new_a[ai] = selected_numbers[index]
  end

  [new_a, new_b]
end
def cross_partial_mapping(a, b)
  new_a = a.dup
  new_b = b.dup

  selected_numbers = a.sample(Random.rand(1...a.size))
  a_indexes = selected_numbers.map { |x| a.index(x) }
  b_indexes = selected_numbers.map { |x| b.index(x) }
  a_mapping = (0...a.size).to_a
  b_mapping = (0...b.size).to_a
  a_indexes.size.times do |i|
    a_mapping[a[a_indexes[i]]] = b[b_indexes[i]]
    b_mapping[b[b_indexes[i]]] = a[a_indexes[i]]
  end

  [
      new_a.map { |x| a_mapping[x] },
      new_b.map { |x| b_mapping[x] }
  ]
end

def cross(a, b)
  cross_partial_mapping(a, b)
end

def mutant(gene)
  # generate a sequence which is longer than 0
  i, j = 0, 0
  loop do
    i = Random.rand(0...gene.size)
    j = Random.rand(0...gene.size)
    i, j = j, i if i > j
    break if i != j
  end

  # reverse the sequence
  ret = gene.dup
  ret[i..j] = ret[i..j].reverse
  ret
end

def do_cross(population)
  (@cross_rate*population.size).to_i.times do
    # generate two different random numbers
    i = Random.rand(0...(population.size))
    j = (i + Random.rand(1...(population.size))) % population.size

    a, b = cross(population[i].last, population[j].last)
    population[i] = [
        0, #fitness(a),
        a
    ]
    population[j] = [
        0, #fitness(b),
        b
    ]
  end
end

def do_mutant(population)
  (@mutant_rate*population.size).to_i.times do
    i = Random.rand(0...population.size)
    path = mutant(population[i].last)
    f = 0 # fitness(path)
    population[i] = [f, path]
  end
end

def gen_population
  Array.new(@population_size) do
    path = (0...@cities.size).to_a.shuffle
    [fitness(path), path]
  end
end

def next_generation(population)
  random = FastRouletteRandom.new(population.reduce([]) { |sum, x| sum << x.first })
  ret = []
  population.size.times do
    index = random.rand
    ret << population[index]
  end
  ret
end

def calc_fitness(population)
  population.size.times do |i|
    population[i] = [fitness(population[i].last), population[i].last]
  end
end

def best(population)
  best_fitness = population.first.first
  best_path = population.first.last
  population.each do |fitness, path|
    if fitness < best_fitness
      best_fitness = fitness
      best_path = path
    end
  end
  [best_fitness, best_path]
end

population = gen_population
max_fitness = 0
best_path = nil

generations = 0

loop do
  population = next_generation(population)
  do_cross(population)
  do_mutant(population)

  calc_fitness(population)
  fitness, path = best(population)

  if generations % 10 == 0
    dis = trip_distance(path)
    printf "gen: %d, fitness: %0.4f, dis: %0.4f, path: #{path.join(' ')}\n", generations, fitness, dis
  end
  if fitness > max_fitness
    max_fitness = fitness
    best_path = path
  end

  generations += 1
  break if generations > @max_generations
end

puts "max fitness: #{max_fitness}, dis: #{trip_distance(best_path)} path: #{(best_path.map { |x| @cities[x].first }).join(' ')}"
#File.write outfile, str