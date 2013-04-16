require 'nokogiri'
require 'find'

@uber_book = {}
@character_order = ['eddard', 'jon', 'daenerys', 'bran', 'tyrion', 'sansa', 'catelyn', 'davos', 'theon', 'samwell', 'cersei', 'brienne', 'extras']

# get file paths for chapters
def find_by_book(book_path)
  chapters = []
  Find.find(book_path) do |p|
    chapters << p if p=~ /.*\.html$/
  end
  chapters
end

def process(chapters, book)
  chapter_count = 1
  chapters.each do |chapter|
    doc = Nokogiri::XML(open(chapter))
    character = get_character(doc, book)
    bookstr = "#{book}, chapter #{chapter_count}"
    if !@character_order.include?(character)
      character = 'extras'
    end
    if @uber_book[character] == nil
      @uber_book[character] = []
    end
    @uber_book[character] << chapter
    chapter_count += 1
  end
end

def get_character(doc, book)
  title = ''
  case book
  when "GOT"
    title = doc.css("h3.calibre5").text
  when "COK"
    title = doc.css("h3.calibre5").text
  when "SOS"
    title = doc.css("p.calibre4").text
  when "FFC"
    title = doc.css("p.calibre4").text
  when "DWD"
    title = doc.css("p.calibre16").text
  end

  return clean_title(title)
end

def clean_title(title)
  title = title.chomp
  title.gsub!("\n", " ")
  title.downcase
end

def chapter_string(count)
  postfix = ''
  if count < 10
    postfix = "00#{count}"
  elsif count < 100
    postfix = "0#{count}"
  else
    postfix = count
  end

  return "./uberbook/asoiaf_#{postfix}.html"
end

def write_toc(toc)
  system "cp template_toc template_toc_temp"
  File.open("template_toc_temp", 'a') do |f|
    toc.each do |t|
      f.write(t)
    end
    f.write("</body></html")
  end
  system "cp template_toc_temp ./uberbook/toc.html"
  system "rm template_toc_temp"
end

def write_metadata(metadata_strs, spine)
  system "rm -rf ./uberbook/META-INF"
  system "cp mimetype ./uberbook/mimetype"
  system "mkdir ./uberbook/META-INF"
  system "cp container.xml ./uberbook/META-INF"
  system "cp template_content template_content_tmp"
  File.open("template_content_tmp", "a") do |f|
    metadata_strs.each do |t|
      f.write(t)
    end
    f.write("</manifest>")
    f.write("<spine toc=\"ncx>\">")
    spine.each do |t|
      f.write(t)
    end
    f.write("</spine>\n")
    f.write("<guide>\n")
    f.write("<reference href=\"titlepage.xhtml\" type=\"cover\" title=\"Cover\"/>\n")
    f.write("</guide>\n")
    f.write("</package\n")
  end
  system "cp template_content_tmp ./uberbook/content.opf"
  system "rm template_content_tmp"
end


def content_opf_string(filename, chapter)
  "\t<item href=\"#{filename}\" id=\"html#{chapter}\" media-type=\"application/xhtml+xml\"/>\n"
end

def spine_string(chapter)
  "\t<itemref idref=\"html#{chapter}\"/>\n"
end

def toc_string(filename, character)
  "\t<p class=\"calibre7\"><a href=\"#{filename}\" class=\"calibre8\">#{character}</a></p>\n"
end

def write_final_book
  puts "Removing existing uberbook"
  system "rm -rf ./uberbook/*html"
  toc = []
  meta_strs = []
  spine = []
  chaptercount = 0
  @character_order.each do |char|
    puts "Writing chapters for #{char}..."
    @uber_book[char].each do |chapter|
      outfile = chapter_string(chaptercount)
      system "cp #{chapter} #{outfile}"
      chapter_file = outfile.split("./uberbook/")[1]
      meta_strs << content_opf_string(chapter_file, chaptercount)
      toc << toc_string(chapter_file, char)
      spine << spine_string(chaptercount)
      chaptercount += 1
    end
  end
  puts "Book written to ./uberbook."
  puts "Writing table of contents..."
  write_toc(toc)
  puts "Writing metadata..."
  write_metadata(meta_strs, spine)
  puts "Combining into ebook..."
  system "rm -rf asoiaf.epub"
  Dir.chdir "uberbook"
  system "zip asoiaf.epub * ./META-INF/*"
  Dir.chdir ".."
  system "mv uberbook/asoiaf.epub ."
end

got_chapters = find_by_book("GOT/")
cok_chapters = find_by_book("COK/")
sos_chapters = find_by_book("SOS/")
ffc_chapters = find_by_book("FFC/")
dwd_chapters = find_by_book("DWD/")

process(got_chapters, "GOT")
process(cok_chapters, "COK")
process(sos_chapters, "SOS")
process(ffc_chapters, "FFC")
process(dwd_chapters, "DWD")

write_final_book
