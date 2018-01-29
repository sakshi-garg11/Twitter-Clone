defmodule Project4 do
  require Logger
  use GenServer
  
  @s 1.3

  def start_link(args) do
    GenServer.start_link(__MODULE__,args,name: {:global,:Server})
  end
  
  def init(args) do
    {:ok,{%{},%{},%{},%{},%{},0,0}}
  end

  def nodesnum(number_of_nodes) do
   
    sum=Enum.sum(Enum.map(1..number_of_nodes,fn(x)->:math.pow(1/x,@s) end))
   
    1/sum
  end
  
  def run(args) do
    Project4.Worker.start_connection(:project4)
    Project4.start_link(args)
    Task.start(fn->loop(-1) end)
    Process.sleep(1_000_000_000)
  end

  def main(args) do
    if elem(args|>List.to_tuple,0)=="run" do
      run(args)

    else
      Project4.Worker.connect(args)
      start=elem(GenServer.call({:global,:Server},{:server,""},:infinity),6) 
      num_node=elem(args|>List.to_tuple,1)
      GenServer.cast({:global,:Server},{:login_added,num_node|>String.to_integer,"",""})
      tweet_count=elem(args|>List.to_tuple,2)  
      Enum.map(1..String.to_integer(num_node),fn(x)->
        Project4.Worker.start_link(Integer.to_string(x+start)|>String.to_atom)
      end)
      
      const=nodesnum(String.to_integer(num_node))*String.to_integer(num_node)
      
      
      
      Enum.map(1..String.to_integer(num_node),fn(x)->
        Task.start(fn->
          inpvar=Enum.take_random(1..(String.to_integer(num_node)+start),(const/:math.pow(x,@s)|>:math.ceil|>round))
          GenServer.cast({:global,(x+start)|>Integer.to_string|>String.to_atom},{:subscribe,inpvar,"",""})
          GenServer.cast({:global,:Server},{:subscribe,(x+start),inpvar,0})
        end)
      end)
      if(length(args)>3) do
        Enum.map(1..String.to_integer(elem(args|>List.to_tuple,3)),fn(x)->
          Task.start(fn->pause(x+start)end)
        end)
      end

      const=nodesnum(String.to_integer(tweet_count))*String.to_integer(tweet_count)
      
      Enum.reduce(1..String.to_integer(num_node),0,fn(x,tweet)->
        Enum.reduce(1..(const/:math.pow(x,@s)|>:math.ceil|>round),tweet,fn(y,tweet)->
         
          new_tweet=tweet+1
          case GenServer.whereis({:global,(x+start)|>Integer.to_string|>String.to_atom})!= nil do
            true -> GenServer.cast({:global,(x+start)|>Integer.to_string|>String.to_atom},{:tweet,tweet,Integer.to_string(:rand.uniform(String.to_integer(num_node)+start)),x+start})
            false ->
          end
          new_tweet
        end)
      end)
      Process.sleep(1_000_000_000)
    end
  end
  
  def loop(oldLength) do
   
    len=elem(GenServer.call({:global,:Server},{:server,""},:infinity),5)
    Logger.debug "Server is running"
    Logger.debug len-oldLength
    
    Process.sleep(1000)
    loop(len)
  end
  
  def pause(x) do
    Process.sleep(1000)
    case (:rand.uniform(100)==2) do
      true ->
      if (GenServer.whereis({:global,x|>Integer.to_string|>String.to_atom})!=nil) do
        GenServer.stop({:global,x|>Integer.to_string|>String.to_atom})
        pause(x)
       else 
        Project4.Worker.start_link(Integer.to_string(x)|>String.to_atom)
        pause(x)
      end
    false->
      pause(x)
    end
  end

  def hash_insert(state, identity, inpvar) do
    hash=elem(state,1)
    inpvariable=Map.get(hash,identity)
    case inpvariable==nil do
      true-> inpvariable=MapSet.put(MapSet.new,inpvar)
      false-> inpvariable=MapSet.put(inpvariable,inpvar)
    end
    hash=Map.put(hash,identity,inpvariable)
    state=Tuple.delete_at(state,1)|>Tuple.insert_at(1,hash)
  end

  def tweeter(state,identity,inpvar) do
    tweet=elem(state,0)
    tweet=Map.put(tweet,identity,inpvar)
    state=Tuple.delete_at(state,0)|>Tuple.insert_at(0,tweet)
  end

  def mentions(state, identity, inpvar) do
    mention=elem(state,2)
    inpvariable=Map.get(mention,identity)
    case inpvariable==nil do
      true -> inpvariable=MapSet.put(MapSet.new,inpvar)
      false -> inpvariable=MapSet.put(inpvariable,inpvar)
    end
    mention=Map.put(mention,identity,inpvariable)
    state=Tuple.delete_at(state,2)|>Tuple.insert_at(2,mention)
  end

  def user(state,inpvar, identity) do
  login= elem(state,4)
  tweet=Map.get(login,inpvar,MapSet.new)
  tweet=MapSet.put(tweet,identity)
  login=Map.put(login,inpvar,tweet)
  state=Tuple.delete_at(state,4)|>Tuple.insert_at(4,login)
  end

  def seen(state, number,identity,inpvar) do
    Enum.map(Map.get(elem(state,3),identity,MapSet.new)|>MapSet.to_list,fn(x)->
      case GenServer.whereis({:global,x|>Integer.to_string|>String.to_atom}) != nil do
        true ->  GenServer.cast({:global,x|>Integer.to_string|>String.to_atom},{:seen, number, inpvar,x})
        false ->  GenServer.cast({:global,:Server},{:login,number,x,0})
      end
  end)
  end

  def new_user(state, inpvar, identity) do
    inpvar=elem(state,6)
    inpvar=inpvar+identity
    state=Tuple.delete_at(state,6)|>Tuple.insert_at(6,inpvar)
  end

  def handle_cast({message, identity, inpvar, number },state) do
     cond do 
     message == :hashtags_insert->
      hash_insert(state, identity,inpvar)

     message == :tweets->
      tweeter(state,identity,inpvar)

     message == :mentions->
      mentions(state, identity, inpvar)

     message == :subscribe->
        subscribe=elem(state,3)
        inpvariable=MapSet.new(inpvar)
        subscribe=Map.put(subscribe,identity,inpvariable)
        state=Tuple.delete_at(state,3)|>Tuple.insert_at(3,subscribe)
        
      message == :login->
        user(state,inpvar, identity) 

     message == :inpvar->
        inpvar=elem(state,5)
        inpvar=inpvar+1
        state=Tuple.delete_at(state,5)|>Tuple.insert_at(5,inpvar)

     message == :seen->
      seen(state, number,identity,inpvar)  

     message == :login_added->
      new_user(state, inpvar, identity)
     end
     {:noreply,state}
  end

  def handle_call({message,name},_from,state) do
    reply=""
    cond do
     message == :mentions->
        mention=elem(state,2)
        result=Map.get(mention,"@"<>Integer.to_string(name),MapSet.new)
        tweet=elem(state,0)
        reply={tweet,result}
     message == :server->
        reply=state
     message == :hashtags->
        hashtags=elem(state,1)
        tweet=elem(state,0)
        reply={tweet,hashtags}
      message == :login->
        tweet=elem(state,0)
        login=elem(state,4)
        reply={login,tweet}
        login=Map.put(login,name,MapSet.new)
        state=Tuple.delete_at(state,4)|>Tuple.insert_at(4,login)        
    end
    {:reply,reply,state}
  end
end
