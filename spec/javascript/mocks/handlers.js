import { http, HttpResponse } from 'msw';

export const handlers = [
  http.post('/pipelines/1/harvest_definitions/1/transformation_definitions/1/fields', () => {
    return HttpResponse.json({
      id: 3,
      name: 'Additional Field',
      block: '',
      created_at: '2026-01-03T00:00:00.000Z',
    });
  }),
];
