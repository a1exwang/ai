infile, outfile = ARGV

@cities = (File.read infile).split("\n")[1..-1]
@cities.map! do |city|
  name, x, y = city.split
  [name, x.to_f, y.to_f]
end

def distance(city_a, city_b)
  Math.sqrt((city_a[1] - city_b[1]) ** 2 + (city_a[2] - city_b[2]) ** 2)
end
def trip_distance(ary)
  len = ary.size
  ary << ary.first
  d = 0.0
  len.times do |i|
    index_a = ary[i]
    index_b = ary[i+1]
    d += distance(@cities[index_a], @cities[index_b])
  end
  d
end
def get_neighbor(s)
  # generate a sequence which is longer than 0
  i, j = 0, 0
  loop do
    i = Random.rand(0...s.size)
    j = Random.rand(0...s.size)
    i, j = j, i if i > j
    break if i != j
  end

  # reverse the sequence
  ret = s[0...-1]
  ret[i..j] = ret[i..j].reverse
  ret
end

def poss_func(e, next_e, temp)
  p = Math.exp((e - next_e) / temp)
  puts p
  p
end

MAX_TIMES = 25
MAX_UNCHANGED_TIMES = 15
T_STEP = 0.99999

s = Array.new(@cities.size) { |x| x }
en = trip_distance(s)
temp = 1
en_unchanged_times = 0

loop do
  temp *= T_STEP

  times = 0

  last_en = en
  loop do
    neighbor = get_neighbor(s)
    neighbor_en = trip_distance(neighbor)

    if neighbor_en < en ||
        Random.rand(0..1.0) < poss_func(en, neighbor_en, temp)

      s = neighbor
      en = neighbor_en
    end
    times += 1
    break if times > MAX_TIMES
  end

  if last_en == en
    en_unchanged_times += 1
  else
    en_unchanged_times = 0
  end
  break if en_unchanged_times > MAX_UNCHANGED_TIMES

  printf "%0.7f %0.7f #{s.join(' ')}\n", temp, en
  #break if temp < 0.0001
end

puts outfile