import http from 'k6/http';
import { check, sleep } from 'k6';

// The Test Requirements: 15 minutes total
export const options = {
  stages: [
    { duration: '2m', target: 200 },   // Ramp up to 200 virtual users over 2 mins
    { duration: '12m', target: 200 },  // Hold steady for 12 minutes (The Soak)
    { duration: '1m', target: 0 },     // Ramp down safely over 1 min
  ],
};

export default function () {
  // ⚠️ REQUIREMENT: Replace with your actual ALB URL from the AWS Console!
  // It should look something like: http://internal-wordpress-alb-12345.eu-north-1.elb.amazonaws.com
  const albUrl = 'http://wordpress-hosting-alb-2144210470.eu-north-1.elb.amazonaws.com';

  // Array of your clients
  const clients = [
    'client3.babu-lahade.online',
    'client4.babu-lahade.online',
    'client5.babu-lahade.online'
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