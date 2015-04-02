require 'redmine'
require 'open-uri'
require 'issue'

Redmine::Plugin.register :redmine_wiki_sql do
  name 'Redmine Wiki SQL Read Only'
  author 'Yu Kabutoya'
  author_url 'https://github.com/kabutoya/redmine_wiki_sql'
  description 'Allows you to run SQL(Read Only) queries and have them shown on your wiki in table format'
  version '0.0.1'

  Redmine::WikiFormatting::Macros.register do
    desc "Run SQL query"
    macro :sql do |obj, args, text|

        _sentence = args.join(",")
        _sentence = _sentence.gsub("\\(", "(")
        _sentence = _sentence.gsub("\\)", ")")
        _sentence = _sentence.gsub("\\*", "*")
        _sentence = WikiSqlHelper.sanitize(_sentence)

        result = ActiveRecord::Base.connection.execute(_sentence)
        text = ''
        unless result.nil?
          _thead = WikiSqlHelper.create_thead_from(result)
          _tbody = WikiSqlHelper.create_tbody_from(result)
          text = WikiSqlHelper.wrap_table_from(_thead, _tbody)
        end
        text.html_safe
    end
  end
end

class WikiSqlHelper
  class << self
    def sanitize(sentence)
      #最低限の無害化(SQL準拠の構文の範囲内)を実施する。(ストプロや権限変更はDB固有が多く面倒なので対応しない。)
      if sentence =~ /insert\s+into.+/i  \
      || sentence =~ /update\s+.+set.+/i \
      || sentence =~ /delete\s+from.+/i  \
      || sentence =~ /truncate\s+.+/i    \
      || sentence =~ /^create.+/i then
        #出力しようとしたSQLを表示させたいが下手なSQLインジェクション起こしそうなので固定のSQLを出力。
        return "select 'bad sql' as col"
      end
      return sentence
    end

    def create_thead_from(result)
      #カラム名を取得。（theadなので配列の先頭要素からのみで良い。）
      column_names = result.fields;
      _thead = '<thead class="ftThead"><tr>'
      count = 0;
      column_names.each do |column_name|
        _thead << '<th class="col_' + count.to_s + '"><p class="fixed">' + column_name + '</p></th>'
        count += 1;
      end
      _thead << '</tr></thead>'
      return _thead
    end

    def create_tbody_from(result)
      _tbody = '<tbody class="ftTbody">';
      result.each do |record|
        unless record.nil?
          _tbody << '<tr>'
          count = 0;
          record.each do |value|
            if value.instance_of?(Array)
                v = value[1].to_s.gsub(/\r\n/,"<br />")
            else
                v = value.to_s.gsub(/\r\n/,"<br />")
            end
            _tbody << '<td class="col_' + count.to_s + '">' + v.gsub(/\\r\\n/,"<br />") + '</td>'
            count += 1;
          end
          _tbody << '</tr>'
        end
      end
      _tbody << '</tbody>'
      return _tbody
    end
    
    def wrap_table_from(thead, tbody)
      _s_div = '<div class="ft"><div class="ftHook"><div class="ftTableWrap">';
      _e_div = '</div></div></div>';
      _s_table = '<table class="ftTable">';
      _e_table = '</table>';
      return _s_div << _s_table << thead << tbody << _e_div << _e_table
    end
  end
end