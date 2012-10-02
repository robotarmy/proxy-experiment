require 'pstore' #file store

require 'securerandom' # file store  uuid
require 'ostruct'

module FileStore
  class Object
    attr_accessor :bucket
    attr_reader :key
    attr_accessor :raw_data, :content_type
    def initialize(key,bucket)
      @bucket = bucket
      @key = key
    end
    def indexes=(*args)
      # not implemented
    end
    def store
        bucket.store.transaction do
          struct = OpenStruct.new(:raw_data => self.raw_data,
                         :content_type => self.content_type)

          bucket.store[bucket.keyify(self.key)] = struct
          bucket.store[bucket.keyify('index')] ||= Array.new
          bucket.store[bucket.keyify('index')] << bucket.keyify(self.key)
        end
        puts "commited #{bucket.keyify(self.key)}"
    end
  end 

  class Bucket
    attr_accessor :name, :store, :key
    def initialize(name,store)
      @name = name
      @store = store
    end
    def get_or_new(key)
      Object.new(key,self)
    end
    def keyify(*args)
      ([self.name] | args).join(':')
    end
  end
  class Stamp
    def next
      SecureRandom.uuid
    end
  end

  class IndexSet
    attr_accessor :bucket
    def initialize(bucket)
      self.bucket = bucket 
    end
    def each(&block)
      index = []
      bucket.store.transaction(true) do
        index = bucket.store[bucket.keyify('index')]
      end
      index.each do | key |
        block.call( key )
      end
    end
  end

  class Result
    attr_accessor :bucket
    def initialize(bucket)
      self.bucket = bucket
    end

    def [](keyified)
      obj = nil
      self.bucket.store.transaction(true) do
        obj = self.bucket.store[keyified]
      end
      if obj == nil
        raise "#{keyified} Object has no value "
      end
      obj
    end
  end

  class Client
    attr_reader :store
    def initialize(*args)
      storage_path = "./filestore.pstore"
      @store = PStore.new(storage_path)
    end
    def bucket(name)
      Bucket.new(name,@store)
    end
    def [](name)
      Result.new(self.bucket(name))
    end
    def stamp
      Stamp.new
    end
    def get_index(name,*rest)
      IndexSet.new(self.bucket(name))
    end
  end
end


