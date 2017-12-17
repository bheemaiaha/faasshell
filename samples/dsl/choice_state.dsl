asl([task('FirstState',"/whisk.system/utils/echo",[]),
     choices('ChoiceState',
             [case('NumericEquals'(foo,1),
                   [task('FirstMatchState',"hello",[result_path(first_match_state)]),
                    task('NextState',"hello",[result_path(next_state)])]),
              case('NumericEquals'(foo,2),
                   [task('SecondMatchState',"hello",[result_path(second_match_state)]),
                    task('NextState',"hello",[result_path(next_state)])])],
             [default([fail('DefaultState',
                            [error("DefaultStateError"),cause("No Matches!")])])])]).
