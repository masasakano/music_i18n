# -*- coding: utf-8 -*-

# Common module for uploading a CSV file
#
# @example
#   include ModuleUploadCsv
#
# == NOTE
#
module ModuleUploadCsv
  #def self.included(base)
  #  base.extend(ClassMethods)
  #end
  extend ActiveSupport::Concern  # In Rails, the 3 lines above can be replaced with this.

  # Allowed maximum lines (including blank lines!)
  MAX_LINES = 250

  #module ClassMethods
  #end

  # Core routine to populate CSV file and return Hash
  #
  # @example for list to create Musics
  #   hsret = populate_csv_file(uploaded_io, in_redirect_path: new_music_url, in_redirect_path_invalid_encoding: musics_path){ |csv_str|
  #     Music.populate_csv(csv_str)
  #   }
  #
  # @param uploaded_io [IO, String] uploaded_io for the CSV file or String
  # @param in_redirect_path: [String] Recommended to specify (e.g., +new_music_url+) though not mandatory (+root_path+ in Default)
  # @param in_redirect_path_invalid_encoding: [NilClass, String] In default, the same as in_redirect_path
  # @return [Hash, NilClass] if falsy, something went wrong.
  # @yield routine to populate
  def populate_csv_file(uploaded_io, in_redirect_path: root_path, in_redirect_path_invalid_encoding: nil)
    in_redirect_path_invalid_encoding ||= in_redirect_path
    if uploaded_io.blank?
      return _format_if_err_in_csv("No CSV file is specified.", in_redirect_path)
    end
    original_filename = (uploaded_io.respond_to?(:original_filename) ? uploaded_io.original_filename : "STDIN")

    csv_str = (uploaded_io.respond_to?(:gsub) ? uploaded_io : uploaded_io.read.force_encoding('UTF-8'))
    msg = sprintf "Controller(%s): CSV file (Size=%d[bytes]) uploaded by User(ID=%d): (%s)", self.class.name, csv_str.bytesize, current_user.id, original_filename
    logger.info msg

    if !csv_str.valid_encoding?
      return _format_if_err_in_csv("Uploaded file contains an invalid sequence as UTF-8 encoding.", in_redirect_path_invalid_encoding)
    end

    nlines = csv_str.chomp.split.size
    msg = sprintf "CSV file (%s): nLines=%d, nChars=%d", original_filename, nlines, csv_str.size
    logger.info msg

    begin
      if nlines > MAX_LINES
        csv_str = csv_str.chomp.split[0, MAX_LINES].join("\n")
        msg1 = "WARNING: CSV file "
        msg2 = sprintf "(%s) ", original_filename
        msg3 = sprintf "is trimmed to %d lines from %d lines.", MAX_LINES, nlines
        logger.warn msg1+msg2+msg3
        add_flash_message(:warning, msg1+msg3)  # defined in application_controller.rb
      end
      return yield(csv_str)
    rescue => er
      # Without rescuing, the error message might not be recorded anywhere.
      msg = "ERROR in Music.populate_csv: err="+er.inspect
      logger.error msg
      warn msg
      raise
    end

    raise "Should never reach here."
  end

  private

    # Core routine to format in erroneous cases
    def _format_if_err_in_csv(msg_alert, in_redirect_path)
      respond_to do |format|
        format.html { redirect_to in_redirect_path, alert: msg_alert } # , notice: msg_alert
        format.json { head :no_content }
      end
      nil
    end
    private :_format_if_err_in_csv

end

