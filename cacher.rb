#!/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'yaml'
require 'fileutils'
require 'concord_cacher'

SKIP_CACHE = false

def main
  FileUtils.rm_rf 'tmp'  rescue nil
  FileUtils.rm_rf 'dist' rescue nil
  mkdir 'tmp/cache/resources'
  mkdir 'tmp/cache/jars'
  mkdir 'dist'

  jnlps = YAML.load_file("./jnlps.yml")
  jnlps.each do |name,opts|
    puts "Processing #{name}"

    # force certain opts to be certain values
    opts["vendor"] = "ConcordConsortium"
    opts["product_name"] = "General"
    opts["product_version"] = "1.0"
    opts["wrapped_jnlp"] = opts.delete(:jnlp)
    opts["install_if_not_found"] = "true"
    opts["cache_loc"] = "jars"
    opts["jnlp2shell.compact_paths"] = "true"
    opts["jnlp2shell.read_only"] = "true"
    # opts["jnlp2shell.static_www"] = "true"
    # opts["jnlp2shell.mirror_host"] = "jars.dev.concord.org"

    # Cache the files with concord_cacher
    cacher_opts = {
      :url => opts["wrapped_jnlp"],
      :cache_dir => "tmp/cache/resources/",
      :skip => [
        /^http:\/\/.*concord\.org[\/]?$/,
        /\/dev(?:\d+)?$/,
        /jar$/
      ]
    }
    puts "Caching otml resources..."
    Concord::JavaProxyCacher.new(cacher_opts).cache unless SKIP_CACHE
    # Cache the jars with jcl
    puts "Caching jnlp resources..."
    `java -cp ./jcl.jar org.concord.JnlpCacher #{opts["wrapped_jnlp"]} tmp/cache/jars` unless SKIP_CACHE
    # Generate jar properties file
    File.open("tmp/jnlp.properties", "w") {|f|
      write_properties(f, opts)
    }
    # Generate custom launcher jar
    customize_jcl(name)
    FileUtils.rm("tmp/jnlp.properties")
  end
  # move the cache into dist
  FileUtils.mv("tmp/cache", "dist/")
  `cd dist && tar czf cache.tar.gz cache/`
end

# TODO Generate a valid properties file
def write_properties(file, props)
  puts "writing properties"
  file.write('<?xml version="1.0" encoding="UTF-8"?>' + "\n")
  file.write('<!DOCTYPE properties SYSTEM "http://java.sun.com/dtd/properties.dtd">' + "\n")
  file.write('<properties>' + "\n")
  props.each do |k,v|
    file.write(%!  <entry key="#{k}">#{v}</entry>\n!)
  end
  file.write('</properties>' + "\n")
end

def customize_jcl(name)
  puts "customizing jcl"
  tmp_jar = "tmp/jcl-#{name}.jar"
  FileUtils.cp('jcl.jar', tmp_jar)
  puts `jar -uf #{tmp_jar} -C tmp jnlp.properties`
  FileUtils.mv(tmp_jar, "dist/")
end

def mkdir(folder)
  begin
    FileUtils.mkdir_p folder
  rescue Errno::EEXIST
  end
end

main