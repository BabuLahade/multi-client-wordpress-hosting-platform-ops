import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '2m', target: 1100 }, 
    { duration: '3m', target: 1100 }, 
    { duration: '1m', target: 0 },    
  ],
};

export default function () {
  // REPLACE WITH YOUR RAW ALB DNS NAME
  const albUrl = 'http://wordpress-hosting-alb-2144210470.eu-north-1.elb.amazonaws.com' ;

  // We use a random number to route 90% of traffic to Client 1, and 10% to Client 2
  const rand = Math.random();

  if (rand < 0.90) {
    // 90% of the traffic (The Viral Client)
    let res = http.get(albUrl, {
      headers: { 'Host': 'client3.babu-lahade.online' }, 
    });
    check(res, { 'Client 1 status 200': (r) => r.status === 200 });
  } else {
    // 10% of the traffic (The Quiet Client)
    let res = http.get(albUrl, {
      headers: { 'Host': 'client4.babu-lahade.online' }, 
    });
    check(res, { 'Client 2 status 200': (r) => r.status === 200 });
  }

  sleep(1);
}