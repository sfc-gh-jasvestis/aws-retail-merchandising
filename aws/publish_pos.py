"""Publish simulated point-of-sale (POS) events to Amazon Data Firehose (stream <prefix>-pos).

Firehose batches the records into S3 (pos/); Snowpipe loads them into RAW.LIVE_POS.
Merchandise line IDs come from RAW.MERCH_LINES (MLN-0000..MLN-0047). Values are seeded random.
"""
import argparse
import json
import random
import time
from datetime import datetime, timezone


def make_event(rng):
    exception = rng.random() < 0.08
    return {'line_id': f'MLN-{rng.randint(0, 47):04d}',
            'event_ts': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3],
            'amount_sgd': round((65 if exception else 28) * rng.lognormvariate(0, 0.5), 2),
            'price_gap_bps': round((950 if exception else 120) * rng.lognormvariate(0, 0.4)),
            'status': 'EXCEPTION' if exception else 'OK',
            'sent_ms': int(time.time() * 1000)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--region', default='us-west-2')
    ap.add_argument('--prefix', default='sg-retail-merchandising')
    ap.add_argument('--count', type=int, default=40)
    ap.add_argument('--seed', type=int)
    args = ap.parse_args()
    import boto3
    firehose = boto3.client('firehose', region_name=args.region)
    stream = f'{args.prefix}-pos'
    rng = random.Random(args.seed)
    records = [{'Data': (json.dumps(make_event(rng)) + '\n').encode()} for _ in range(args.count)]
    for start in range(0, len(records), 500):
        out = firehose.put_record_batch(DeliveryStreamName=stream, Records=records[start:start + 500])
        if out['FailedPutCount']:
            raise RuntimeError(f"{out['FailedPutCount']} records were rejected by Firehose")
    print(f'published {args.count} POS events to Firehose stream {stream}; S3 delivery buffers up to 60 s')


if __name__ == '__main__':
    main()
