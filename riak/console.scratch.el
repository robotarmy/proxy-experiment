
;; clear the requests bucket
;;

lists:foreach(
  fun (X) ->
    C:delete(<<"requests">>,X)
  end, hd(tl(tuple_to_list(C:list_keys(<<"requests">>))))
).

;; check to see if they are empty

C:list_keys(<<"requests">>).

