# 文本分类作业文档

## 朴素贝叶斯

- 思路
    - 将每一类所有文档合并成一个文档, 用空格替换所有符号, 以空格分词
    - 统计每一类中每个词的个数存入@doc_types\[c\]\[word\]中
    - 对一篇测试文章中的每一个单词w, 对每一个类型c计算(@doc_types\[c\]\[w\] + 1) / (total_words + type_words\[c\])的和
    - 取和最大的那个类
    
## SVM
    - 主要就是将文档转换成libsvm支持的格式