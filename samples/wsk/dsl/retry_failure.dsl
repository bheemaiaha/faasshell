asl([task('HelloWorld',"frn:wsk:functions:::function:helloPython",
          [timeout_seconds(2),
           retry([case('ErrorEquals'(["CustomError"]),
                       [interval_seconds(1),max_attempts(2),backoff_rate(2.0)]),
                  case('ErrorEquals'(["States.TaskFailed"]),
                       [interval_seconds(3),max_attempts(2),backoff_rate(2.0)]),
                  case('ErrorEquals'(["States.ALL"]),
                       [interval_seconds(1),max_attempts(3),backoff_rate(2.0)])
   ])])]).
