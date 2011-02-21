# encoding: utf-8
#
#	cowtech-lib
#	Author: Shogun <shogun_panda@me.com>
#	Copyright © 2011 and above Shogun
# Released under the MIT License, which follows.
#
# The MIT License
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

require "rexml/document"
require "open4"
require "find"
require "fileutils"

module CowtechLib
  module Lib
    # A class which provides some useful method for interaction with files and processes.
    # @author Shogun
    class Shell
      # Run a command.
      # 
      # Arguments:
      # * <em>msg</em>: The message to show
      # * <em>cmd</em>: The command to run
      # * <em>show_msg</em>: If show the exit message
      # * <em>show_exit</em>: If show the exit code
      # * <em>fatal</em>: If abort on failure
      # 
      # Returns: An object which the status attribute is the exit status of the process, and the output attribute is the output of the command
      def run(msg, cmd, show_msg = true, show_exit = true, fatal = false)
        rv = {:status => 0, :output => []}
        command = args[:command]

        @console.write(:begin => args[:msg]) if args[:msg]

        if @console.show_commands then
          @console.warn("Will run command: \"#{command}\"", :dots => false)
          @command.status(:ok)
        end

        unless @console.skip_commands == true then
          rv[:status] = Open4::open4(cmd + " 2>&1") { |pid, stdin, stdout, stderr|
            stdout.each_line do |line|
              rv[:output] << line
              print line if @console.show_outputs
            end
          }.exitstatus
        end
        rv[:output] = rv[:output].join("\n")

        self.status(rv[:status] == 0 ? :ok : :fail) if args[:show_exit]
        rv
      end

      # Opens a file.
      # 
      # Arguments:
      # * <em>name</em>: The file path
      # * <em>mode</em>: Open mode, like the one in File.new
      # * <em>codec</em>: The encoding used to open the file. <b>UNUSED FOR NOW!</b>
      # 
      # Returns: A new <em>File</em> object
      def open_file(*args)
        begin
          File.new(args[:name], args[:mode] || "r" + (args[:codec] : ? ":#{args[:codce]}" : ""))
        rescue Exception => e
          @console.write(:error => "Unable to open file #{name}: #{e}")
          nil
        end
      end

      # Perform a check on a file or directory.
      # 
      # Arguments:
      # * <em>name</em>: The file/directory path
      # * <em>tests</em>: A list of tests to execute
      # 
      # Valid tests are:
      # 
      # * <em>:fc_exists</em>: Check if the file exists
      # * <em>:fc_read</em>: Check if the file is readable
      # * <em>:fc_write</em>: Check if the file writeable
      # * <em>:fc_exec</em>: Check if the file executable
      # * <em>:fc_dir</em>: Check if the file is a directory
      # * <em>:fc_symlink</em>: Check if the file is symbolic link
      # 
      # Returns: <em>true</em> if any of tests had success, <em>false</em> otherwise
      def file_check?(*args)
        rv = false
        tests = args[:tests].to_a

        if args[:file] then
          rv = true
          tests.each do |test| 
            rv = rv && FileTest.try((test.to_s + "?").to_sym, args[:file]) 
          end
        end

        rv
      end

      # Delete files/directories.
      # 
      # Arguments:
      # * <em>files</em>: List of entries to delete
      # * <em>exit_on_fail</em>: Whether abort on failure
      # * <em>show_error</em>: Whether show errors occurred
      # 
      # Returns: <em>true</em> if operation had success, <em>false</em> otherwise.
      def delete_files!(*args)
        rv = true
        files = args[:files].to_a

        begin
          FileUtils.rm_r(files, {:noop => @console.skip_commands, :verbose => @console.skip_commands, :secure => true})
        rescue StandardError => e
          if args[:show_errors] == true then
            if e.message =~ /^Permission denied - (.+)/ then
              @console.error("Cannot remove following non writable entry: #{$1}", :dots => false, :fatal => args[:fatal])
            elsif e.message =~ /^No such file or directory - (.+)/) then
              @console.error("Cannot remove following non existent entry: #{$1}", :dots => false, :fatal => args[:fatal])
            end
          end

          rv = false
        rescue Exception => e
          if args[:show_error] == true then
            @console.error("Cannot remove following entries:", :dots => false)
            @console.indent_region(3) do
              files.each do |afile|
                @console.write(:msg => afile, :dots => false)
              end
            end
            @console.write(:msg => "#{@console.indentator * @console.indent_level}due to an error: #{e}\n", :dots => false, :fatal => args[:fatal])
          end

          rv = false
        end

        rv ? rv : self.status(:fail, :fatal => args[:fatal])
      end

      # Create directories (and any missing parent directory).
      # 
      # Arguments:
      # * <em>files</em>: List of directories to create
      # * <em>mode</em>: Octal mode for newly created directories
      # * <em>exit_on_fail</em>: Whether abort on failure
      # * <em>show_error</em>: Whether show errors occurred
      # 
      # Returns: <em>true</em> if operation had success, <em>false</em> otherwise.
      def create_directories(*args)
        rv = true
        files = args[:files].to_a

        files.each do |file| 
          if self.file_check?(:files => file, :tests => :exists) then
            if self.file_check?(:files => file, :tests => :directory) == true then
              @console.error("Cannot create following directory <text style=\"bold white\">#{file}</text> because it already exists.", :dots => false, :fatal => args[:fatal])
            else
              @console.error("Cannot create following directory <text style=\"bold white\">#{file}</text> because it already exists as a file", :dots => false, :fatal => args[:fatal])
            end

            rv = false
          end

          if rv then
            begin
              FileUtils.makedirs(file, {:mode => args[:mode] || 0755, :noop => @console.skip_commands, :verbose => @console.skip_commands})
            rescue StandardError => e
              if args[:show_errors] && e.message =~ /^Permission denied - (.+)/ then
                @console.error("Cannot create following directory in non writable parent: <text style=\"bold white\">#{$1}</text>.", :dots => false, :fatal => args[:fatal])
              end

              rv = false
            rescue Exception => e
              if args[:show_error] == true then
                @console.error("Cannot create following directory:", :dots => false)
                @console.indent_region(3) do
                  files.each do |afile|
                    @console.write(:msg => afile, :dots => false)
                  end
                end
                @console.write("#{@console.indentator * @console.indent_level}due to an error: #{e}\n", :dots => false, :fatal => args[:fatal])
              end

              rv = false
            end
          end

          break unless rv
        end

        rv ? rv : self.status(:fail, :fatal => args[:fatal])
      end

      # Copy files to a destination directory.
      # 
      # Arguments:
      # * <em>files</em>: List of entries to copy/move
      # * <em>dest</em>: Destination file/directory
      # * <em>must_move</em>: Move instead of copy
      # * <em>dest_is_dir</em>: Whether destination is a directory
      # * <em>exit_on_fail</em>: Whether abort on failure
      # * <em>show_error</em>: Whether show errors occurred
      # 
      # Returns: <em>true</em> if operation had success, <em>false</em> otherwise.
      def copy(*args)
        rv = true
        move = args[:move]

        # If we are copy or moving to a directory
        if args[:destination_is_directory] then
          files = (args[:files] || []).to_a
          dest = args[:dest]
          dest += "/" if self.file_check?(dest, :directory) and dest !~ /\/$/

          files.each do |file|
            begin
              if move == true then
                FileUtils.move(file, dest, {:noop => @console.skip_commands, :verbose => @console.skip_commands})
              else
                FileUtils.cp_r(file, dest, {:noop => @console.skip_commands, :verbose => @console.skip_commands, :remove_destination => true})
              end
            rescue StandardError => e
              if args[:show_errors] && e.message =~ /^Permission denied - (.+)/ then
                self.error("Cannot #{if must_move then "move" else "copy" end} entry <text style=\"bold white\">#{file}</text> to non-writable entry <text style=\"bold white\">#{dest}</text>", false, false, false) if m != nil
              end

              rv = false
            rescue Exception => e
              if args[:show_errors] then
                self.error(, false)
                @console.error("Cannot #{if move then "move" else "copy" end} following entries to <text style=\"bold white\">#{dest}</text>:", :dots => false)
                @console.indent_region(3) do
                  files.each do |afile|
                    @console.write(:msg => afile, :dots => false)
                  end
                end
                @console.write("#{@console.indentator * @console.indent_level}due to an error: #{e}\n", :dots => false, :fatal => args[:fatal])
              end

              rv = false
            end

            break unless rv
          end
        else # If we are copying or moving to a file
          unless files.kind_of?(String) == true and dest.kind_of?(String) == true then
            self.error("Cowtech::Lib::Shell#copy: To copy a single file, both files and dest arguments must be a string.", :dots => false, :fatal => args[:fatal])
            rv = false
          else
            dst_dir = File.dirname(dest)

            unless self.file_check?(:file => dst_dir, :tests => [:exists, :directory]) then
              self.create_directories(:files => dst_dir, :mode => 0755, :fatal => args[:fatal], :show_errors => args[:show_errors])
            end

            begin
              if move == true then
                FileUtils.move(files, dest, {:noop => @console.skip_commands, :verbose => @console.skip_commands})
              else
                FileUtils.cp(files, dest, {:noop => @console.skip_commands, :verbose => @console.skip_commands})
              end
            rescue StandardError => e
              self.error("Cannot #{if move then "move" else "copy" end} entry <text style=\"bold white\">#{files}</text> to non-writable entry<text style=\"bold white\"> #{dest}</text>", :dots => false, :fatal => args[:fatal]) if args[:show_errors] && (e.message =~ /^Permission denied - (.+)/)
              rv = false
            rescue Exception => e
              self.error("Cannot #{if move then "move" else "copy" end} <text style=\"bold white\">#{files}</text> to <text style=\"bold_white\">#{dest}</text> due to an error: <text style=\"bold red\">#{e}</text>", :dots => false, :fatal => args[:fatal]) if args[:show_errors]
              rv = false
            end
          end
        end

        rv ? rv : self.status(:fail, :fatal => args[:fatal])
      end

      # Rename a file.
      # 
      # Arguments:
      # * <em>src</em>: The file to rename
      # * <em>dst</em>: The new name
      # * <em>exit_on_fail</em>: Whether abort on failure
      # * <em>show_error</em>: Whether show errors occurred
      # 
      # Returns: <em>true</em> if operation had success, <em>false</em> otherwise.
      def rename(*args)
        rv = true

        if src.is_a?(String) and dst.is_a?(String) then
          rv = self.copy(:from => src, :to => dst, :show_errors => args[:show_errors], :fatal => args[:fatal])
        else
          @console.error("Cowtech::Lib::Shell#rename: Both :src and :dst arguments must be a string.", :dots => false, :fatal => args[:fatal]) if args[:show_error]
          rv = false
        end

        rv ? rv : self.status(:fail, :fatal => args[:fatal])
      end

      # Returns a list of files in specified paths which matchs one of requested patterns.
      # 
      # Arguments:
      # * <em>paths</em>: List of path in which seach
      # * <em>patterns</em>: List of requested patterns
      # 
      # Returns: List of found files.
      def find_by_pattern(*args)
        # TODO: E se patterns è vuoto?
        rv = []

        paths = args[:paths].to_a
        string_patterns = args[:patterns].to_a

        if paths.length > 0 then
          # Convert patterns to regexp
          patterns = string_patterns.collect do |pattern| 
            pattern.is_a?(Regexp) ? pattern : Regexp.new(pattern, Regexp::IGNORECASE) 
          end

          # For each path
          paths.each do |path|
            Find.find(path) do |file| # Find files
              matchs = false

              patterns.each do |pattern| # Match patterns
                if file =~ pattern then
                  matchs = true
                  break
                end
              end

              rv << file if matchs
            end
          end

          rv
        end
      end

      # Returns a list of files in specified paths which have one of requested extensions.
      # 
      # Arguments:
      # * <em>paths</em>: List of path in which seach
      # * <em>extensions</em>: List of requested extensions
      # 
      # Returns: List of found files.
      def find_by_extension(*args)
        args[:patterns] = (args[:extensions] || "").to_a.collect do |extension| 
          Regexp.new(extension + "$", Regexp::IGNORECASE) 
        end

        self.find_by_pattern(*args)
      end
    end
  end
end