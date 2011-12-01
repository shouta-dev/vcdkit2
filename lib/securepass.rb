#######################################################################################
#
# Copyright 2011 Kaoru Fukumoto All Rights Reserved
#
# You may freely use and redistribute this script as long as this 
# copyright notice remains intact 
#
#
# DISCLAIMER. THIS SCRIPT IS PROVIDED TO YOU "AS IS" WITHOUT WARRANTIES OR CONDITIONS 
# OF ANY KIND, WHETHER ORAL OR WRITTEN, EXPRESS OR IMPLIED. THE AUTHOR SPECIFICALLY 
# DISCLAIMS ANY IMPLIED WARRANTIES OR CONDITIONS OF MERCHANTABILITY, SATISFACTORY 
# QUALITY, NON-INFRINGEMENT AND FITNESS FOR A PARTICULAR PURPOSE. 
#
#######################################################################################
require 'rubygems'
require 'crypt/blowfish'
require 'base64'

module VCloud
  class SecurePass
    def initialize
      @bf = Crypt::Blowfish.new("csjHMi33HXDUyG0D8LvZefw1YVbqjWHzPTYePuqrsrAPDgZAE7dtJ4hJ")
    end
    def random_alphanumeric(size)
      s = ""
      size.times do
        s << (i = Kernel.rand(62); i += ((i < 10) ? 48 : ((i < 36) ? 55 : 61 ))).chr
      end
      s  
    end

    def encrypt(str)
      # Make str 8 bytes aligned
      str += " " * (8 - (str.size % 8))

      # Encrypt string 
      blocks = ''
      base = 0
      (str.size / 8).times do |n|
        blocks << @bf.encrypt_block(str[base..(base+7)])
        base += 8
      end
      Base64.encode64(blocks)
    end

    def decrypt(str)
      ret = ''
      blocks = Base64.decode64(str)
      base = 0
      (blocks.size / 8).times do |n|
        ret << @bf.decrypt_block(blocks[base..(base+7)])
        base += 8
      end
      ret.strip
    end
  end
end

