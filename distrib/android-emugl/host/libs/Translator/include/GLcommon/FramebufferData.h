/*
* Copyright (C) 2011 The Android Open Source Project
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/
#ifndef _FRAMEBUFFER_DATA_H
#define _FRAMEBUFFER_DATA_H

#include "objectNameManager.h"
#include <GLES/gl.h>
#include <GLES/glext.h>

class RenderbufferData : public ObjectData
{
public:
    ~RenderbufferData();

    unsigned int sourceEGLImage = 0;
    void (*eglImageDetach)(unsigned int imageId) = nullptr;
    GLuint attachedFB = 0;
    GLenum attachedPoint = 0;
    GLuint eglImageGlobalTexName = 0;
};

const int MAX_ATTACH_POINTS = 3;

class FramebufferData : public ObjectData
{
public:
    explicit FramebufferData(GLuint name);
    ~FramebufferData();

    void setAttachment(GLenum attachment,
                       GLenum target,
                       GLuint name,
                       ObjectDataPtr obj,
                       bool takeOwnership = false);

    GLuint getAttachment(GLenum attachment,
                         GLenum *outTarget,
                         ObjectDataPtr *outObj);

    void validate(class GLEScontext* ctx);

private:
    inline int attachmentPointIndex(GLenum attachment);
    void detachObject(int idx);

private:
    GLuint m_fbName = 0;
    struct attachPoint {
        GLenum target; // OGL if owned, GLES otherwise
        GLuint name; // OGL if owned, GLES otherwise
        ObjectDataPtr obj;
        bool owned;
    } m_attachPoints[MAX_ATTACH_POINTS+1] = {};
    bool m_dirty = false;
};

#endif