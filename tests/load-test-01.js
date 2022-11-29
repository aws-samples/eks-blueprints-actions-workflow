import http from 'k6/http';
import { sleep } from 'k6';

export const options = {
    duration: '1m',
    vus: 50,
};

export default function () {
    const res = http.get('https://game-2048-eks-demo-dev-01.micbegin.people.aws.dev/');
    sleep(1);
}