import http from 'k6/http';
import { check, sleep } from 'k6';

// The Test Requirements: 15 minutes total
export const options = {
  stages: [
    { duration: '2m', target: 200 },   
    { duration: '12m', target: 200 },  
    { duration: '1m', target: 0 },     
  ],
};

export default function () {
 
  const albUrl = 'http://wordpress-hosting-alb-67884335.eu-north-1.elb.amazonaws.com';

  
  const clients = [
    'client3.babu-lahade.online',
    'client4.babu-lahade.online',
    'client5.babu-lahade.online',
    'client6.babu-lahade.online'
  ];

  // Randomly pick a client for every single request
  const randomClient = clients[Math.floor(Math.random() * clients.length)];

  // Send the request, injecting the Host header so the ALB knows which client to serve
  let res = http.get(albUrl, {
    headers: { 'Host': randomClient },
  });

  // Verify the server didn't crash (returns HTTP 200 OK)
  check(res, { 
    'status is 200': (r) => r.status === 200 
  });

  // Wait 1 second before this specific virtual user clicks again
  sleep(1);
}