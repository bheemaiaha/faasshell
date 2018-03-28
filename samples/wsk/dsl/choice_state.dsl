asl([task('FirstState',"frn:wsk:functions:::function:/whisk.system/utils/echo",[]),
     choices('ChoiceState',
             [case('NumericEquals'('$.foo',1),
                   [task('FirstMatchState',"frn:wsk:functions:::function:hello",
                         [result_path('$.first_match_state')]),
                    task('NextState',"frn:wsk:functions:::function:hello",
                         [result_path('$.next_state')])]),
              case('NumericEquals'('$.foo',2),
                   [task('SecondMatchState',"frn:wsk:functions:::function:hello",
                         [result_path('$.second_match_state')]),
                    task('NextState',"frn:wsk:functions:::function:hello",
                         [result_path('$.next_state')])])],
             [default([fail('DefaultState',
                            [error("DefaultStateError"),cause("No Matches!")])])])]).
