import { NextResponse } from 'next/server';
import { executeQuery } from '@/lib/snowflake';
import { demoPlatform } from '@/lib/platform';

export const dynamic = 'force-dynamic';

// Only these fixed, read-only queries can run. The model never writes SQL; it
// only summarises rows returned here, so every answer is traceable to data.
const INTENTS: Record<string, { match: RegExp; sql: string }> = {
  lines: {
    match: /markdown|line|store|city|worst|highest|delay/i,
    sql: `SELECT ENTITY_ID, ENTITY_NAME, REGION, CATEGORY, EXCEPTION_COUNT, MARKDOWN_COUNT, PROMO_DELAY_COUNT, ROUND(EXCEPTION_MARKDOWN_PCT, 1) AS EXCEPTION_MARKDOWN_PCT
FROM CURATED.PERFORMANCE_SUMMARY
QUALIFY DENSE_RANK() OVER (ORDER BY MARKDOWN_COUNT DESC) <= 3
ORDER BY MARKDOWN_COUNT DESC, EXCEPTION_COUNT DESC`,
  },
  types: {
    match: /type|reason|cause|why|exception|pricing/i,
    sql: `SELECT EXCEPTION_TYPE, EXCEPTION_COUNT, MARKDOWN_COUNT, PROMO_DELAY_COUNT, ROUND(EXCEPTION_MARKDOWN_PCT, 1) AS EXCEPTION_MARKDOWN_PCT
FROM CURATED.EXCEPTION_SUMMARY ORDER BY MARKDOWN_COUNT DESC LIMIT 8`,
  },
  kpis: {
    match: /.*/,
    sql: `SELECT TITLE, DISPLAY, SOURCE_WATERMARK FROM CURATED.KPI_SUMMARY ORDER BY SORT_ORDER`,
  },
};

const DEFINITIONS =
  'Price integrity rate = units sold without a pricing exception / units sold. Exception markdown rate = unplanned markdowns / pricing exceptions raised. ' +
  'A promo setup delay is a promotion that started late after an unplanned markdown. Competitor price campaign exceptions are town-wide (every line in one planning area) and always resolve with a price match, without a markdown. ' +
  'Values are in SGD; merchandise lines are ranged in store clusters in 5 Singapore planning areas (HDB towns). All data is synthetic demo data.';

// provider 'cortex' = Snowflake AI_COMPLETE; 'bedrock' = Amazon Bedrock Claude
// via the external-access UDF APP.BEDROCK_GENERATE (aws/setup_aws.py).
async function summarise(question: string, rows: unknown[], provider: 'cortex' | 'bedrock' = 'cortex'): Promise<string> {
  const prompt =
    'You are a pricing analyst at Tembusu Fresh Mart, a fictional Singapore supermarket chain. Answer ONLY from the JSON rows and definitions below. ' +
    'If the rows do not answer the question, say so. Do not invent numbers. Keep it under 120 words.\n' +
    `Definitions: ${DEFINITIONS}\nRows: ${JSON.stringify(rows)}\nQuestion: ${question}`;
  const out = await executeQuery<{ R: string }>(
    provider === 'bedrock' ? 'SELECT APP.BEDROCK_GENERATE(?) AS R' : `SELECT AI_COMPLETE('claude-sonnet-4-5', ?) AS R`,
    [prompt],
  );
  const raw = String(out[0]?.R ?? '').trim();
  // AI_COMPLETE returns a JSON string literal; decode it when present.
  try {
    const parsed = JSON.parse(raw);
    return typeof parsed === 'string' ? parsed : raw;
  } catch {
    return raw;
  }
}

export async function POST(req: Request) {
  let body: any;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }
  const question = typeof body?.question === 'string' ? body.question.trim().slice(0, 2000) : '';
  const memo = body?.mode === 'memo';
  if (!memo && !question) return NextResponse.json({ error: 'Question required' }, { status: 400 });

  try {
    if (memo) {
      const provider = demoPlatform() === 'aws' ? 'bedrock' : 'cortex';
      const [kpis, lines, types, risk, bands] = await Promise.all([
        executeQuery(INTENTS.kpis.sql),
        executeQuery(INTENTS.lines.sql),
        executeQuery(INTENTS.types.sql),
        executeQuery(`SELECT ENTITY_ID, ROUND(MARKDOWN_PROB_7D, 2) AS MARKDOWN_PROB_7D, RISK_BAND
FROM ML.MARKDOWN_RISK_SCORES ORDER BY MARKDOWN_PROB_7D DESC LIMIT 5`),
        executeQuery(`SELECT RISK_BAND, COUNT(*) AS LINES FROM ML.MARKDOWN_RISK_SCORES GROUP BY RISK_BAND`),
      ]);
      const rows = { kpis, topMarkdownLines: lines, exceptionTypes: types, top5ByRisk: risk, linesPerRiskBand: bands };
      const answer = await summarise(
        'Draft a short action memo for the Head of Pricing and Promotions with 3 prioritised actions, citing the figures.',
        [rows],
        provider,
      );
      return NextResponse.json({ answer, sources: rows, provider: provider === 'bedrock' ? 'Amazon Bedrock (Claude Sonnet 4.5)' : 'Snowflake Cortex AI_COMPLETE (claude-sonnet-4-5)', draft: true, synthetic: true });
    }
    const key = Object.keys(INTENTS).find((k) => INTENTS[k].match.test(question))!;
    const rows = await executeQuery(INTENTS[key].sql);
    const answer = await summarise(question, rows);
    return NextResponse.json({ answer, sql: INTENTS[key].sql, sources: rows, synthetic: true });
  } catch (err) {
    console.error('ask route failed', err);
    return NextResponse.json({ error: 'AI service unavailable' }, { status: 503 });
  }
}
