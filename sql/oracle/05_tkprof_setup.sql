SET ECHO ON
SET TIMING ON
ALTER SESSION SET tracefile_identifier = 'BD2_TRABAJO4';
ALTER SESSION SET statistics_level = ALL;
ALTER SESSION SET sql_trace = TRUE;

@@03_consultas.sql

ALTER SESSION SET sql_trace = FALSE;

PROMPT La traza queda en el directorio de diagnostico de Oracle.
PROMPT En el contenedor se puede ubicar con:
PROMPT find /opt/oracle/diag -name '*BD2_TRABAJO4*.trc'
PROMPT Luego se procesa con:
PROMPT tkprof archivo.trc salida_tkprof.txt sort=exeela,fchela
