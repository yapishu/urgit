// The parent's captured CI run (Delivery 1B correction 01): the attempts and
// plan jobs of the shadow candidate in which the real producer passed and
// the consumer's assignment was refused (`signature does not verify`)
// before any consumer VM ran. Verbatim from
// .scratch/workflow/parent-review-01/SHADOW-FAILURE-DETAIL.json
// (sha-256 0c2820c863f89776dd934408520a22788b7103594a2a3504ad40ce552ba9b6ad),
// the ship's own candidate JSON; not a model.

export const capturedCandidate = {
  "id": "0v3.i0b8r.6gfu1.dnib7.flql9.26aqh",
  "status": "unknown",
  "mode": "shadow",
  "verdictReason": "job consumer in outputs.yml had an infrastructure error",
  "planned": true
}

export const capturedPlan = [
  {
    "timeoutMinutes": null,
    "name": "Outputs across jobs",
    "workflow": "outputs.yml",
    "runsOn": [
      "ubuntu-latest"
    ],
    "decision": null,
    "id": "producer",
    "outputs": [
      {
        "name": "verdict",
        "text": "${{ steps.emit.outputs.raw }}",
        "line": 11,
        "col": 16
      },
      {
        "name": "first",
        "text": "${{ steps.one.outputs.same }}",
        "line": 13,
        "col": 14
      },
      {
        "name": "second",
        "text": "${{ steps.two.outputs.same }}",
        "line": 14,
        "col": 15
      },
      {
        "name": "empty",
        "text": "${{ steps.emit.outputs.blank }}",
        "line": 15,
        "col": 14
      },
      {
        "name": "quoted",
        "text": "${{ steps.emit.outputs.quoted }}",
        "line": 16,
        "col": 15
      },
      {
        "name": "json",
        "text": "${{ steps.emit.outputs.json }}",
        "line": 17,
        "col": 13
      },
      {
        "name": "composed",
        "text": "release-${{ steps.one.outputs.same }}",
        "line": 18,
        "col": 17
      }
    ],
    "stage": 0,
    "if": null,
    "needs": []
  },
  {
    "timeoutMinutes": null,
    "name": "Outputs across jobs",
    "workflow": "outputs.yml",
    "runsOn": [
      "ubuntu-latest"
    ],
    "decision": null,
    "id": "consumer",
    "outputs": [],
    "stage": 1,
    "if": {
      "refusal": null,
      "text": "needs.producer.outputs.verdict == 'go' && needs.producer.result == 'success'",
      "line": 38,
      "col": 9,
      "legacy": false
    },
    "needs": [
      "producer"
    ]
  },
  {
    "timeoutMinutes": null,
    "name": "Outputs across jobs",
    "workflow": "outputs.yml",
    "runsOn": [
      "ubuntu-latest"
    ],
    "decision": null,
    "id": "stopped-consumer",
    "outputs": [],
    "stage": 1,
    "if": {
      "refusal": null,
      "text": "needs.producer.outputs.verdict == 'stop'",
      "line": 61,
      "col": 9,
      "legacy": false
    },
    "needs": [
      "producer"
    ]
  }
]

export const capturedConsumer = {
  "status": "infrastructure-error",
  "jobOutputs": null,
  "finished": 1792125669,
  "job": "consumer",
  "daemon": "0v2.mp2v9.f4m52.fqnh1.il3ur.q1bc6",
  "approval": null,
  "stepOutputs": [],
  "workflow": "outputs.yml",
  "decision": {
    "verdict": "run",
    "value": "true",
    "reason": "if \"needs.producer.outputs.verdict == 'go' && needs.producer.result == 'success'\" is true"
  },
  "manifest": "0v6.ook6m.cleet.kr7ie.v4msk.en4mv",
  "events": 0,
  "generation": 3,
  "mode": "shadow",
  "kind": "job",
  "pinned": [],
  "sandbox": "vm",
  "attempt": "0v2.nq828.o1jkt.cceve.b87pm.1a3iq",
  "log": null,
  "network": "locked",
  "outcome": "known",
  "needs": [
    {
      "status": "passed",
      "job": "producer",
      "outputs": [
        {
          "name": "verdict",
          "cut": false,
          "value": "go"
        },
        {
          "name": "first",
          "cut": false,
          "value": "from-one"
        },
        {
          "name": "second",
          "cut": false,
          "value": "from-two"
        },
        {
          "name": "empty",
          "cut": false,
          "value": ""
        },
        {
          "name": "quoted",
          "cut": false,
          "value": "it's \"quoted\"\nsecond line"
        },
        {
          "name": "json",
          "cut": false,
          "value": "{\"n\":0,\"ok\":false,\"list\":[\"a\",\"b\"]}"
        },
        {
          "name": "composed",
          "cut": false,
          "value": "release-from-one"
        }
      ],
      "attempt": "0v1.v0vt1.7tat1.h1ae4.k5u8g.4devu",
      "result": "success"
    }
  ],
  "reason": "abandoned: assignment refused: signature does not verify",
  "started": 1792125669,
  "trust": "trusted",
  "stepOutputCount": 0
}

export const capturedStoppedConsumer = {
  "status": "skipped",
  "jobOutputs": null,
  "finished": 1792125669,
  "job": "stopped-consumer",
  "daemon": null,
  "approval": null,
  "stepOutputs": [],
  "workflow": "outputs.yml",
  "decision": {
    "verdict": "skip",
    "value": "false",
    "reason": "if \"needs.producer.outputs.verdict == 'stop'\" is false"
  },
  "manifest": "0v0",
  "events": 0,
  "generation": 3,
  "mode": "shadow",
  "kind": "job",
  "pinned": [],
  "sandbox": "vm",
  "attempt": "0v2.lt5f7.leh37.82vcb.76jm3.sd59l",
  "log": null,
  "network": "locked",
  "outcome": "known",
  "needs": [
    {
      "status": "passed",
      "job": "producer",
      "outputs": [
        {
          "name": "verdict",
          "cut": false,
          "value": "go"
        },
        {
          "name": "first",
          "cut": false,
          "value": "from-one"
        },
        {
          "name": "second",
          "cut": false,
          "value": "from-two"
        },
        {
          "name": "empty",
          "cut": false,
          "value": ""
        },
        {
          "name": "quoted",
          "cut": false,
          "value": "it's \"quoted\"\nsecond line"
        },
        {
          "name": "json",
          "cut": false,
          "value": "{\"n\":0,\"ok\":false,\"list\":[\"a\",\"b\"]}"
        },
        {
          "name": "composed",
          "cut": false,
          "value": "release-from-one"
        }
      ],
      "attempt": "0v1.v0vt1.7tat1.h1ae4.k5u8g.4devu",
      "result": "success"
    }
  ],
  "reason": "if \"needs.producer.outputs.verdict == 'stop'\" is false",
  "started": 1792125669,
  "trust": "trusted",
  "stepOutputCount": 0
}

export const capturedProducer = {
  "status": "passed",
  "jobOutputs": [
    {
      "name": "verdict",
      "error": null,
      "cut": false,
      "value": "go",
      "redacted": false
    },
    {
      "name": "first",
      "error": null,
      "cut": false,
      "value": "from-one",
      "redacted": false
    },
    {
      "name": "second",
      "error": null,
      "cut": false,
      "value": "from-two",
      "redacted": false
    },
    {
      "name": "empty",
      "error": null,
      "cut": false,
      "value": "",
      "redacted": false
    },
    {
      "name": "quoted",
      "error": null,
      "cut": false,
      "value": "it's \"quoted\"\nsecond line",
      "redacted": false
    },
    {
      "name": "json",
      "error": null,
      "cut": false,
      "value": "{\"n\":0,\"ok\":false,\"list\":[\"a\",\"b\"]}",
      "redacted": false
    },
    {
      "name": "composed",
      "error": null,
      "cut": false,
      "value": "release-from-one",
      "redacted": false
    }
  ],
  "finished": 1792125669,
  "job": "producer",
  "daemon": "0v2.mp2v9.f4m52.fqnh1.il3ur.q1bc6",
  "approval": null,
  "stepOutputs": [
    {
      "name": "raw",
      "cut": false,
      "step": [
        "emit"
      ],
      "value": "go",
      "redacted": false
    },
    {
      "name": "blank",
      "cut": false,
      "step": [
        "emit"
      ],
      "value": "",
      "redacted": false
    },
    {
      "name": "undeclared",
      "cut": false,
      "step": [
        "emit"
      ],
      "value": "never published",
      "redacted": false
    },
    {
      "name": "quoted",
      "cut": false,
      "step": [
        "emit"
      ],
      "value": "it's \"quoted\"\nsecond line",
      "redacted": false
    },
    {
      "name": "json",
      "cut": false,
      "step": [
        "emit"
      ],
      "value": "{\"n\":0,\"ok\":false,\"list\":[\"a\",\"b\"]}",
      "redacted": false
    },
    {
      "name": "same",
      "cut": false,
      "step": [
        "one"
      ],
      "value": "from-one",
      "redacted": false
    },
    {
      "name": "same",
      "cut": false,
      "step": [
        "two"
      ],
      "value": "from-two",
      "redacted": false
    }
  ],
  "workflow": "outputs.yml",
  "decision": {
    "verdict": "run",
    "value": null,
    "reason": "no prerequisites"
  },
  "manifest": "0vjn2f3.562p1.va0f7.h5fks.e3442",
  "events": 27,
  "generation": 3,
  "mode": "shadow",
  "kind": "job",
  "pinned": [],
  "sandbox": "vm",
  "attempt": "0v1.v0vt1.7tat1.h1ae4.k5u8g.4devu",
  "log": {
    "size": 12899,
    "key": "ci/wf1b-outputs/0v3.i0b8r.6gfu1.dnib7.flql9.26aqh/0v1.v0vt1.7tat1.h1ae4.k5u8g.4devu/trusted/log.jsonl",
    "sha256": "ccd422ae96c6fcf9bc62bd2a566d4cfc2617d16fe24a5e8ef2d55d023a829f9f"
  },
  "network": "locked",
  "outcome": "known",
  "needs": [],
  "reason": null,
  "started": 1792125664,
  "trust": "trusted",
  "stepOutputCount": 7
}
