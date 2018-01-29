defmodule Project4.Worker do
    require Logger
    use GenServer

    def connect(args) do
       
        Project4.Worker.start_connection(:project4,:ok)
        inpvar="project4@"<>(args|>List.to_tuple|>elem(0))
        ping=Node.ping :"#{inpvar}"
        case ping == :pong do
            true ->
            Logger.debug ("connection established  Successfully")
            Process.sleep(1000)
           
            false ->
            Logger.debug ("Connection cannot be established, try again")
            Process.exit(self(),2);
        end
    end
  
    def genvalue({login,tweet},name) do
        reply=Enum.map(Map.get(login,name,MapSet.new)|>MapSet.to_list,fn(x)->
            Map.get(tweet,x)
        end)
        reply 
    end
    def start_link(args) do
        map=elem(GenServer.call({:global,:Server},{:server,""},:infinity),3)
        #IO.inspect {"closing values "<>Atom.to_string(args),genvalue(GenServer.call({:global,:Server},{:login,args|>Atom.to_string|>String.to_integer},:infinity),args|>Atom.to_string|>String.to_integer)}
        GenServer.start_link(__MODULE__,map,name: {:global,args})
    end

    def init(args) do
        {:ok,{args,%{},%{}}} 
    end

  def handle_call({message,name},_from,state) do
    reply=""
    cond do
      message == :mentions->
         tup=GenServer.call({:global,:Server},{message,name},:infinity)
         tweet=elem(tup,0)
         mentions=elem(tup,1)
        Enum.map(MapSet.to_list(mentions),fn(x)->
            Logger.debug Map.get(tweet,x,"")  
        end)
      message ==  :hashtags->
         tup=GenServer.call({:global,:Server},{message,name},:infinity)
         tweet=elem(tup,0)
         hashtags=elem(tup,1)
         Enum.map(Map.get(hashtags,name,MapSet.new)|>MapSet.to_list,fn(x)->
            Logger.debug Map.get(tweet,x,"")   
         end)
    end
    {:reply,reply,state}
  end

   def tweets(state,tweet_message,counts, name) do
    Logger.debug "Tweet from "<> Integer.to_string(name)
    tweet=elem(state,1)
    case Map.get(tweet,counts) == nil do
        true ->
        GenServer.cast({:global,:Server},{:inpvar,0,0,0})
        
        map=SocialParser.extract(tweet_message,[:hashtags,:mentions])
        Enum.map(Map.get(map,:hashtags,[]),fn(x)->
            GenServer.cast({:global,:Server},{:hashtags_insert,x,counts,0})
        end)
        Enum.map(Map.get(map,:mentions,[]),fn(x)->
            if GenServer.whereis({:global,String.replace_prefix(x,"@","")|>String.to_atom}) != nil do
                GenServer.cast({:global,String.replace_prefix(x,"@","")|>String.to_atom},{:mention,counts,tweet_message,name})
            end
            GenServer.cast({:global,:Server},{:mentions,x,counts,0})
        end)
        GenServer.cast({:global,:Server},{:tweets,counts,tweet_message,0})
        GenServer.cast({:global,:Server},{:seen,name,tweet_message,counts})
        tweet=Map.put(tweet,counts,tweet_message)
        state=Tuple.delete_at(state,1)|>Tuple.insert_at(1,tweet)
       false ->
    end
   end

   def retweets(state, counts, name, tweet_message) do
    tweet=elem(state,1)
    tweet_message=Map.get(tweet,counts,nil)
    case tweet_message != nil do
        true ->
        GenServer.cast({:global,:Server},{:inpvar,0,0,0})
        Logger.debug "ReTweet from "<>Integer.to_string(name)
        GenServer.cast({:global,:Server},{:seen,name,tweet_message,counts})
        false ->
    end
   end

    def handle_cast({message,counts,tweet_message,name},state) do
        cond do
           message == :tweet-> 
             tweets(state,tweet_message,counts, name)

            message == :retweet->
                retweets(state, counts, name, tweet_message) 
                
           message == :mention->
                mention=elem(state,2)
                mention=Map.put(mention,counts,tweet_message)
                state=Tuple.delete_at(state,2)|>Tuple.insert_at(2,mention)
          message == :subscribe->
                map=elem(state,0)
                map=MapSet.new(counts)
                state=Tuple.delete_at(state,0)|>Tuple.insert_at(0,map)
                
          message == :seen->
                case :rand.uniform(50)==2 do
                    true ->
                    GenServer.cast({:global,name|>Integer.to_string|>String.to_atom},{:retweet,counts,tweet_message,name})
                    false ->
                end
                tweet=elem(state,1)
                tweet=Map.put(tweet,counts,tweet_message)
                state=Tuple.delete_at(state,1)|>Tuple.insert_at(1,tweet)
        end        
    {:noreply,state}
    end

 def start_connection(application,server\\:error) do
      unless Node.alive?() do
        local_node_name = create_name(application,server)
        {:ok, _} = Node.start(local_node_name)
      end
      cookie = Application.get_env(application, :cookie)
      Node.set_cookie(cookie)
    end
  
    def create_name(application,server) do
      {:ok,iplist}=:inet.getif()
      system = Application.get_env(application, :system, iplist|>List.first|>Tuple.to_list|>List.first|>Tuple.to_list|>Enum.join("."))
      hex=
        cond do
          server == :error-> ""
          server == :ok->  :erlang.monotonic_time() |>
              :erlang.phash2(256) |>
              Integer.to_string(16)
        end
      String.to_atom("#{application}#{hex}@#{system}")
    end
  
end