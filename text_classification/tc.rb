#!/usr/bin/env ruby
require 'json'
DATA_PATH = 'data'
MINIMUM_WORD_LENGTH = 4

def file_to_dict(file)
  dict = Hash.new(0)
  wc = 0
  (File.read(file).force_encoding('iso-8859-1').downcase.each_char.map do |c|
    (c =~ /[a-z]/) ? c : ' '
  end).join.split.each do |w|
    if w.size >= MINIMUM_WORD_LENGTH
      if dict[w] == 0
        yield(w) if block_given?
      end
      wc += 1
      dict[w] += 1
    end
  end
  [wc, dict]
end

def each_file(train)
  `ls #{DATA_PATH}`.split.each_with_index do |dir, type_index|
    files = `find #{File.join(DATA_PATH, dir)} -type f`.split("\n")
    # 取每一类前一半训练, 后一半作为测试集
    data_set = train ? files.first(files.size / 2) : files.last(files.size / 2)
    data_set.each { |file| yield(type_index, file) }
  end
end

def svm_gen_file(word_id, train, name)
  str = ''
  sorted_word_id = word_id.sort_by{|item|item.last}.map {|item| [item.first.to_s, item.last.to_s]}
  each_file(train) do |type_index, file|
    puts file
    _, dict = file_to_dict(file)
    dict.default = '0'
    line = "#{type_index} "
    sorted_word_id.each do |word, id|
      line += "#{id}:#{dict[word]} "
    end
    str += line + "\n"
  end
  File.write(name, str)
end

if ARGV[0] == 'init'
  @total_word_count = 0
  @type_word_count = Hash.new(0)
  @doc_types = Hash.new { Hash.new }
  @diff_word_count = 0
  @word_id = {}

  each_file(true) do |type_index, file|
    puts file
    wc, dict = file_to_dict(file) { |w| @word_id[w] = @diff_word_count; @diff_word_count += 1 }
    @doc_types[type_index] = @doc_types[type_index].merge(dict) { |_, old, new| (old || 0) + (new || 0) }
    @type_word_count[type_index] += wc
    @total_word_count += wc
  end
  json = {
      total_word_count: @total_word_count,
      type_word_count: @type_word_count,
      doc_types: @doc_types,
      word_id: @word_id
  }
  File.write('init.json', json.to_json)
else
  json = JSON.parse File.read('init.json')
  word_id = json['word_id']
  if ARGV[0] == 'svm-train'
    svm_gen_file(word_id, true, 'train.svm')
    puts `svm-train -c 10 -g 0.000057 train.svm`
  elsif ARGV[0] == 'svm-test'
    svm_gen_file(word_id, false, 'test.svm')
    puts `svm-predict test.svm train.svm.model a.txt`
  else #ARGV[0] == 'bayers'
    @total_word_count = json['total_word_count']
    @type_word_count = json['type_word_count']
    @doc_types = json['doc_types']
    correct, total = 0, 0
    each_file(false) do |type_index, file|
      @values = {}
      _, words_dict = file_to_dict(file)
      @doc_types.each do |type, words|
        val = Math.log(@type_word_count[type].to_f / @total_word_count)
        words_dict.each do |word, count|
          val += count * Math.log(((words[word] || 0) + 1).to_f / (@total_word_count + @type_word_count[type]))
        end
        @values[type] = val
      end
      max_type = (@values.sort_by { |_key, val| val }).last.first
      if max_type == type_index.to_s
        correct += 1
      else
        puts '!' * 60, @values
      end
      total += 1
    end
    puts "correct rate: #{100.0 * correct / total}%"
  end
end
