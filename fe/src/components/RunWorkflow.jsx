import * as React from 'react'
import { ci } from '../api'
import { makeRunWorkflow } from '../runWorkflowComponent.js'

// The CI tab's Run workflow form (Delivery 1A): the component built against
// React, with the same-origin, session-authorized ci API. Its behaviour
// lives in runWorkflowComponent.js, runWorkflowView.js and ciDispatch.js,
// which the tests drive.
export default makeRunWorkflow(React, { ci })
