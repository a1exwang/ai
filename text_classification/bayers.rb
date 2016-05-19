require 'json'

DATA_PATH = 'data'

def file_to_words(file)
  (File.read(file).force_encoding('iso-8859-1').split("\n\n")[1..-1].join.each_char.map do |x|
    c = x.downcase
    n, a, z = (c + 'az').unpack('C*')
    (a <= n && n <= z) ? c : ' '
  end).join.split.reject {|x| x.size <= 3 }
end

def calc_words_from_file(file, words)
  n = 0
  file_to_words(file).each do |x|
    words[x] += 1
    @total_words += 1
    n += 1
  end
  n
end

if ARGV[0] == 'init'
  @total_words = 0
  @type_word_count = {}
  @doc_types = {}
  `ls #{DATA_PATH}`.split.each do |dir|
    type = dir.split('_').first
    @doc_types[type] = Hash.new(0)
    @type_word_count[type] = 0
    # 取每类前一半作为训练集
    files = `find #{File.join(DATA_PATH, type)}* -type f`.split("\n")
    files.first(files.size / 2).each do |file|
      puts file
      @type_word_count[type] += calc_words_from_file(file, @doc_types[type])
    end
  end
  json = {
      total_words: @total_words,
      type_word_count: @type_word_count,
      doc_types: @doc_types
  }
  File.write('init.json', json.to_json)
else
  json = JSON.parse File.read('init.json')
  @total_words = json['total_words']
  @type_word_count = json['type_word_count']
  @doc_types = json['doc_types']
  @correct = 0
  @total = 0

  `ls #{DATA_PATH}`.split.each do |dir|
    doc_type = dir.split('_').first
    # 取每一类后一半作为测试集
    files = `find #{File.join(DATA_PATH, doc_type)}* -type f`.split("\n")
    files.last(files.size).each do |file|
      @values = {}
      words_in_file = file_to_words(file)
      @doc_types.each do |type, words|
        val = Math.log(@type_word_count[type].to_f / @total_words)
        words_in_file.each do |word|
          val += Math.log(((words[word] || 0) + 1).to_f / (@total_words + @type_word_count[type]))
        end
        @values[type] = val
      end
      max_type = (@values.sort_by { |_, val| val }).last.first
      if max_type == doc_type
        @correct += 1
      else
        puts '!' * 60
        puts @values
      end
      @total += 1
    end
  end
  puts "correct rate: #{@correct.to_f / @total * 100}%"
end
