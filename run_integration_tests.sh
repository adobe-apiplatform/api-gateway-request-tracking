#!/usr/bin/env bash
make test-docker-jenkins
while docker ps | grep test_gateway_1  ; do
    echo "Waiting for tests to finish"
    sleep 5
done
echo "Finished integration tests"
make post-docker-test
if ! docker logs test_gateway_1 --tail 1 | grep "PASS" ; then
    echo "FAILED TESTS"
    docker logs test_gateway_1
    cd ./test && docker-compose -f docker-compose-jenkins.yml stop && docker-compose -f docker-compose-jenkins.yml rm -f
    exit 64
fi
docker logs test_gateway_1 --tail 1
cd ./test && docker-compose -f docker-compose-jenkins.yml stop && docker-compose -f docker-compose-jenkins.yml rm -f

