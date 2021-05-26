docker run -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=Test_1234' -p 1433:1433 -d microsoft/mssql-server-linux:2017-latest

# NEED an environment with python 3.8 and all the dependencies
export PYTHONPATH='./tests'
export TPP_DATABASE_URL=mssql://sa:Test_1234@127.0.0.1:1433/master
export OPENSAFELY_BACKEND=graphnet

pytest tests/test_tpp_backend.py::test_patients_registered_practice_as_of
